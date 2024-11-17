import os
import openai
import re
from dotenv import load_dotenv
from langchain_community.embeddings import HuggingFaceInstructEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain.chains import RetrievalQA
from langchain_core.language_models.chat_models import BaseChatModel
import requests
from openai import OpenAI

def preprocess_text(text):
    # Lowercase the text
    text = text.lower()
    # Remove punctuation
    text = re.sub(r'[^\w\s]', '', text)
    return text    

def load_text_files_from_folder(folder_path):
    texts = {}
    for filename in os.listdir(folder_path):
        if filename.endswith('.txt'):
            file_path = os.path.join(folder_path, filename)
            with open(file_path, 'r', encoding='utf-8') as file:
                texts[filename] = file.read()
    return texts

def load_text_files(file_paths):
    texts = {}
    for file_path in file_paths:
        with open(file_path, 'r', encoding='utf-8') as file:
            texts[file_path] = file.read()
    return texts

def create_prompt_for_rag(texts, topic):
    combined_text = "\n\n".join(
        f"File: {filename}\n{text}" for filename, text in texts.items()
    )
    prompt = (
        f"{combined_text}\n\n"
        f"Question: I have attached transcripts of discussion-based audio before this. "
        f"Tell me if the following topic, phrase, or concept is discussed in any of the previous transcripts. "
        f"Give me the exact sentence or multiple sentences that you think the topic appears or is mentioned in. "
        f"Topic: {topic}\nAnswer:"
    )
    return prompt

def generate_response(query, retrieved_docs, llm):
    # Combine the query and retrieved content into a prompt
    context = "\n\n".join(doc['content'] for doc in retrieved_docs)
    prompt = f"Context:\n{context}\n\nQuestion: {query}\nAnswer:"

    # Generate the response using the LLM
    response = llm.generate(prompt)
    return response

class SambaNovaLLM(BaseChatModel):
    def __init__(self, api_key, model_name):
        self.api_key = api_key
        self.model_name = model_name

    def generate(self, prompt):
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": self.model_name,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "top_p": 0.1
        }
        response = requests.post("https://api.sambanova.com/v1/chat/completions", headers=headers, json=data)
        response.raise_for_status()
        return response.json()['choices'][0]['message']['content']

    def invoke(self, prompt):
        # This method is required by BaseChatModel
        return self.generate(prompt)

def retrieve_and_rerank(query, vector_store, top_n=5):
    # Embed the query
    query_embedding = embedding_model.embed_query(query)

    # Retrieve relevant content
    retriever = vector_store.as_retriever()
    retrieved_docs = retriever.retrieve(query_embedding, top_n=top_n)

    # Rerank the retrieved documents (if needed)
    # For simplicity, assume the retriever returns documents in order of relevance
    return retrieved_docs

# -------------------------------------------------------------------------------
load_dotenv()

samba_key = os.getenv('SAMBANOVA_API_KEY')
print(samba_key)

# Audio-to-text stuff
oai_key = os.getenv('OPENAI_API_KEY')
transcript_client = OpenAI(api_key=oai_key)

# audio_file= open("sample.mp3", "rb")
# transcription = transcript_client.audio.transcriptions.create(
#   model="whisper-1", 
#   file=audio_file
# )
# print(transcription.text)

# --- Search process
client = openai.OpenAI(
    api_key=samba_key,
    base_url="https://api.sambanova.ai/v1",
)

file_paths = ''
folder_path = './test_docs'
texts = load_text_files_from_folder(folder_path)

embedding_model = HuggingFaceInstructEmbeddings()
vector_store = Chroma.from_texts(list(texts.values()), embedding_model)

# Define RAG Chain w/ SambaNova
sambanova_llm = SambaNovaLLM(api_key=samba_key, model_name='Meta-Llama-3.1-8B-Instruct')

# Define a retrieval-augmented generation chain
rag_chain = RetrievalQA(
    retriever=vector_store.as_retriever(),
    llm=sambanova_llm
)
query = "What is the strawberry model?"
retrieved_docs = retrieve_and_rerank(query, vector_store)
response = generate_response(query, retrieved_docs, sambanova_llm)

print("Response:", response)
