from ollama import Client
from config_conversational import ConversationalConfigManager, Options, Prompt
import argparse


class ConversationalLlmManager():
    def __init__(self, options: Options, active_prompt: Prompt):
        self.options = options
        self.active_prompt = active_prompt
        self.client = Client(
            host=self.options.host
        )
        self.eos: bool = False
        self.messages: list = []
        self.messages.append(self.add_message("system", self.get_formatted_prompt(self.active_prompt)))
        self.last_user_message = self.add_message("user", "")

    def update_active_prompt(self, active_prompt: Prompt):
        self.active_prompt = active_prompt
        self.clear_messages()

    def update_options(self, options: Options):
        self.options = options

    def add_message(self, role: str, content: str):
        message = {
            "role": role,
            "content": content
        }
        return message

    def clear_messages(self):
        self.messages.clear()
        self.messages.append(self.add_message("system", self.get_formatted_prompt(self.active_prompt)))

    def get_formatted_prompt(self, prompt_name: str) -> str:
        formatted_prompt = self.active_prompt.prompt

        if self.active_prompt.appends.get('language'):
            formatted_prompt += f" The answer MUST be in {self.active_prompt.appends.get("language")}."
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
        if input == self.options.eom:
            self.messages.append(self.last_user_message)
            self.last_user_message = self.add_message("user", "")
            self.send_messages()

        if input == self.options.eos:
            self.eos = True

        self.last_user_message["content"] = input

    def send_messages(self):
        print(self.messages)
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

        current_message = self.add_message("assistant", "")
        self.messages.append(current_message)
        current_sentence = ""
        current_response = ""
        for chunk in stream:
            current_token = chunk["message"]["content"]
            self.messages[-1]["content"] = current_response

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


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Executes a NLP task on a single line of text utilising ollama as a conversation")
    parser.add_argument("--config", default="./config_conversational.yaml", help="The config file to load")
    parser.add_argument("--prompt", default="default", help="The prompt's name")
    args = parser.parse_args()

    config_manager = ConversationalConfigManager(args.config)
    llm_manager = ConversationalLlmManager(config_manager.get_options(), config_manager.get_prompt(args.prompt))

    while not llm_manager.eos:
        current_line = input()
        llm_manager.process_text(current_line)
