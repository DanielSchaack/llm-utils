from ollama import Client
from config import Options, Prompt
import asyncio


class EndOfService(Exception):
    def __init__(self, message):
        super().__init__(message)


class ConversationalLlmManager():
    def __init__(self, options: Options, active_prompt: Prompt):
        self.options = options
        self.active_prompt = active_prompt
        self.client = Client(
            host=self.options.host
        )
        self.eos: bool = False
        self.message_queue = asyncio.Queue()
        self.messages: list = []
        self.add_message("system", self.get_formatted_prompt(self.active_prompt), False)
        self.last_user_message = self.new_message("user", "")

    def update_active_prompt(self, active_prompt: Prompt):
        self.active_prompt = active_prompt
        self.clear_messages()

    def update_options(self, options: Options):
        self.options = options

    def new_message(self, role: str, content: str):
        message = {
            "role": role,
            "content": content
        }
        return message

    def add_message(self, role: str, content: str, add_to_queue: bool = True):
        message = self.new_message(role, content)
        self.messages.append(message)
        if add_to_queue:
            self.message_queue.put_nowait(message)

    def clear_messages(self):
        self.messages.clear()
        self.add_message("system", self.get_formatted_prompt(self.active_prompt))

    def get_formatted_prompt(self, prompt_name: str) -> str:
        formatted_prompt = self.active_prompt.prompt

        if self.active_prompt.appends.get('language'):
            formatted_prompt += f" The answer MUST be in {self.active_prompt.appends.get('language')}."
        else:
            formatted_prompt += " The answer MUST be in the same language as the user provided."

        if self.active_prompt.appends.get("summarize"):
            formatted_prompt += self.active_prompt.appends.get("summarize")

        if self.active_prompt.appends.get("questioning"):
            formatted_prompt += self.active_prompt.appends.get("questioning")

        if self.active_prompt.appends.get("concise"):
            formatted_prompt += self.active_prompt.appends.get("concise")

        if self.active_prompt.appends.get("new_lines"):
            formatted_prompt += self.active_prompt.appends.get("new_lines")

        return formatted_prompt

    def process_text(self, input: str):
        if not input:
            return

        if input == self.options.eom:
            self.add_message("user", self.last_user_message["content"])
            self.send_messages()
            return

        if input == self.options.eos:
            self.eos = True
            self.add_message("", "")
            return

        self.last_user_message["content"] = input

    def send_messages(self):
        stream = self.client.chat(
            model=self.active_prompt.model,
            messages=self.messages,
            stream=self.options.stream,
            keep_alive=self.active_prompt.keep_alive,
            options={
                'temperature': 0.0,
                'num_predict': 1024.0,
                'top_p': 0.1
            }
        )

        current_sentence = ""
        current_response = ""
        for chunk in stream:
            current_token = chunk["message"]["content"]
            if self.options.stream:
                if "\n" in current_token:
                    print(current_sentence)
                    current_sentence = ""
                    current_response += current_token
                    continue

            current_sentence += current_token
            current_response += current_token

        if self.options.stream:
            print(current_sentence)
        else:
            print(current_response)

        self.add_message("assistant", current_response)

