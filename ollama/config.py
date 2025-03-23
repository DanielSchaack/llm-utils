import yaml
import os
from typing import Optional
from dataclasses import dataclass, field


@dataclass
class Append:
    language: str = ""
    summarize: str = " You will respond by firstly briefly summarizing my thinking."
    questioning: str = " You will pose a remark or question to challenge my assumptions or to explore alternative perspectives."
    concise: str = " Keep your responses brief and focused on prompting further exploration."
    new_lines: str = " You MUST append a new line after each sentence."


@dataclass
class Prompt:
    model: str = "gemma3:latest"
    prompt: str = "You are a thoughtful and inquisitive assistant. I will present you with a problem, idea, or decision to be elaborated on."
    keep_alive: int = 60
    appends: Append = field(default_factory=Append)


@dataclass
class Options:
    host: str = "http://localhost:11434"
    stream: bool = True
    eom: str = "<><>"
    eos: str = ">><<"
    print_to_terminal: bool = True
    server: bool = False
    single_time: bool = False


@dataclass
class Config:
    options: Options = field(default_factory=Options)
    prompts: dict[str, Prompt] = field(default_factory=dict)


class ConversationalConfigManager:
    def __init__(self, config_path: str = None):
        self.config_path = config_path
        self.config = Config()
        if config_path:
            self.load_config(self.config_path)

    def load_config(self, config_path: str = None):
        if config_path:
            self.config_path = config_path

        if self.config_path:
            assert os.path.exists(self.config_path), "Config file must exist"
            with open(self.config_path, 'r') as file:
                raw_config = yaml.safe_load(file)

            if "options" in raw_config:
                self.config.options = Options(**raw_config["options"])

            if "prompts" in raw_config:
                prompts_list = raw_config["prompts"]
                for prompt_dict in prompts_list:
                    for key, value in prompt_dict.items():
                        self.config.prompts[key] = Prompt(**value)

    def save_config(self, config_path: str = None):
        if config_path:
            self.config_path = config_path

        if self.config_path:
            with open(self.config_path, 'w') as file:
                yaml.dump(self.config.__dict__, file, default_flow_style=False, sort_keys=False)

    def get_available_prompts(self) -> list[str]:
        return list(self.config.prompts.keys())

    def get_prompt(self, prompt_name: str) -> Optional[Prompt]:
        return self.config.prompts.get(prompt_name)

    def add_prompt(self, name: str, prompt_config: Prompt):
        self.config.prompts[name] = prompt_config

    def remove_prompt(self, name: str) -> bool:
        if name in self.config.prompts:
            del self.config.prompts[name]
            return True
        return False

    def get_options(self) -> Options:
        return self.config.options

    def set_options(self, options: Options):
        self.config.options = options

