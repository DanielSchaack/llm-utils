from config import ConversationalConfigManager
from ollama_conversational import ConversationalLlmManager
import argparse
import json
import threading
import logging
import sys

from aiohttp import web, http_exceptions
from aiohttp.web_runner import GracefulExit
from aiohttp_sse import sse_response

import asyncio

logging.basicConfig(filename="app.log", filemode="w", level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
log = logging.getLogger(__name__)


def read_and_process_stdin():
    while not llm_manager.eos:
        current_line = input()
        llm_manager.process_text(current_line)


async def async_read_and_process_stdin():
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await asyncio.get_event_loop().connect_read_pipe(lambda: protocol, sys.stdin)

    while not llm_manager.eos:
        line = await reader.readline()
        line = line.decode().strip()
        process_thread = threading.Thread(target=llm_manager.process_text, args=(line,))
        process_thread.start()
        # llm_manager.process_text(line)
    raise GracefulExit


async def start_background_tasks(app):
    app['stdin_task'] = asyncio.create_task(async_read_and_process_stdin())


async def cleanup_background_tasks(app):
    for task_name in ['stdin_task']:
        if task_name in app:
            app[task_name].cancel()
            try:
                await app[task_name]
            except asyncio.CancelledError:
                pass


async def get_all_items(queue: asyncio.Queue) -> list:
    items: list = []
    while len(items) == 0 or not queue.empty():
        item = await queue.get()
        items.append(item)
        queue.task_done()
        if item["role"] == "" or queue.empty():
            break
    return items


async def get_item(queue: asyncio.Queue) -> list:
    item = None
    while not item:
        item = await queue.get()
        queue.task_done()
    return item


current_messages: list = []


async def event_stream(request: web.Request) -> web.StreamResponse:
    global current_messages
    async with sse_response(request) as resp:
        while resp.is_connected():
            if len(current_messages) == 0:
                current_messages.append(await get_item(llm_manager.message_queue))
            if llm_manager.eos:
                raise GracefulExit
            data = json.dumps(current_messages)
            try:
                await resp.send(data)
                current_messages.clear()
            except Exception as e:
                log.error(e)
                resp.force_close()
                break
    return resp


async def get_all_messages(request: web.Request) -> web.Response:
    data = llm_manager.messages
    return web.json_response(json.dumps(data))


async def add_message(request: web.Request) -> web.Response:
    if request.can_read_body:
        try:
            body = await request.text()
            llm_manager.process_text(body)
            llm_manager.process_text(config_manager.get_options().eom)
        except Exception as ex:
            print(ex)
            log.error(ex)
            raise http_exceptions.HttpBadRequest
    else:
        log.error("Add Message Request has no body")
        raise http_exceptions.HttpBadRequest
    return web.Response()


async def delete_messages(request: web.Request) -> web.Response:
    global current_messages
    current_messages.clear()
    llm_manager.clear_messages()
    return web.Response()


async def index(request):
    return web.FileResponse('index.html')


def run_app():
    app = web.Application()
    app.router.add_get("/messages-stream", event_stream)
    app.router.add_get("/messages", get_all_messages)
    app.router.add_post("/messages", add_message)
    app.router.add_delete("/messages", delete_messages)
    app.router.add_get("/", index)
    app.on_startup.append(start_background_tasks)
    app.on_cleanup.append(cleanup_background_tasks)
    web.run_app(app=app, host="127.0.0.1", port=42069)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Executes a NLP task on a single line of text utilising ollama as a conversation")
    parser.add_argument("--config", default="./config.yaml", help="The config file to load")
    parser.add_argument("--prompt", default="default", help="The prompt's name")
    args = parser.parse_args()

    config_manager = ConversationalConfigManager(args.config)
    llm_manager = ConversationalLlmManager(config_manager.get_options(), config_manager.get_prompt(args.prompt))

    try:
        if config_manager.get_options().server:
            run_app()
        else:
            read_and_process_stdin()
    except Exception as e:
        log.error(e)
        pass
