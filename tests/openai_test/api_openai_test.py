import os
import openai

openai.api_key = "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"
# openai.api_base = "https://api.openai.com/v1"
openai.api_base = "https://api.openai.forsearcher.com/v1"

completion = openai.ChatCompletion.create(
  model="gpt-3.5-turbo",
  messages=[
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "你好"}
  ]
)

print(completion.choices[0].message.get("content", ""))
