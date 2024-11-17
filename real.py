import os
import openai
import re
from dotenv import load_dotenv
import requests
from openai import OpenAI

class SambaNovaAgent:
    def __init__(self, api_key, model_name):
        self.api_key = api_key
        self.model_name = model_name

    def create_prompt(texts, query):
        combined_text = "\n\n".join(texts.values())
        prompt = f"{combined_text}\n\nQuestion: {query}\nAnswer:"
        return prompt
    
    def process_text(self, text, samba_key, prompt):
    # Prepare a simple prompt for checking the presence of the topic        
        client = openai.OpenAI(
            api_key=samba_key,
            base_url="https://api.sambanova.ai/v1",
        )
        
        response = client.chat.completions.create(
            model='Meta-Llama-3.1-8B-Instruct',
            messages=[{"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": f'"Text: {text}\n\n" . This is my prompt: {prompt}'}],
            temperature=0.1,
            top_p=0.1
        )

        return response.choices[0].message.content
    
def refine_with_sambanova(text, topic, sambanova_agent, samba_key):
    prompt = (
        f"Text: {text}\n\n"
        f"Question: Identify the sentences or areas where the topic '{topic}' is discussed, "
        f"even if mentioned indirectly. Provide the relevant sentences or sections, "
        f"but limit the response to unique sentences or sections."
    )

    # Use SambaNova's API to refine the search
    return sambanova_agent.process_text(text, samba_key, prompt)


def consolidate_results_and_refine(results, topic, sambanova_agent, texts, samba_key):
    # Categorize files based on the relevance response
    categorized_results = {
        'definitely': [],
        'moderately': [],
        'barely': [],
        'not_mentioned': []
    }

    detailed_results = {}

    for filename, result in results.items():
        result_lower = result.lower()
        if 'yes (definitely)' in result_lower:
            categorized_results['definitely'].append(filename)
        elif 'yes (moderately)' in result_lower:
            categorized_results['moderately'].append(filename)
        elif 'yes (barely)' in result_lower:
            categorized_results['barely'].append(filename)
        else:
            categorized_results['not_mentioned'].append(filename)

    # Refine results for 'definitely', 'moderately', and 'barely' relevant files
    for category in ['definitely', 'moderately', 'barely']:
        for filename in categorized_results[category]:
            refined_result = refine_with_sambanova(texts[filename], topic, sambanova_agent, samba_key)
            detailed_results[filename] = refined_result

    return {
        'categorized_results': categorized_results,
        'detailed_results': detailed_results
    }

def load_text_files_from_folder(folder_path):
    texts = {}
    for filename in os.listdir(folder_path):
        if filename.endswith('.txt'):
            file_path = os.path.join(folder_path, filename)
            with open(file_path, 'r', encoding='utf-8') as file:
                texts[filename] = file.read()
    return texts

def main():
    # Load environment variables
    load_dotenv()
    samba_key = os.getenv('SAMBANOVA_API_KEY')
    model_name = 'Meta-Llama-3.1-70B-Instruct'

    # Initialize the SambaNova agent
    sambanova_agent = SambaNovaAgent(api_key=samba_key, model_name=model_name)

    # Load text files
    folder_path = './test_docs'
    texts = load_text_files_from_folder(folder_path)

    # Process each text file with an agent
    topic = "strawberry model"
    prompt = (
        f"Question: Is the topic '{topic}' discussed in this text at all? If so, rate the level of relevance."
        f"Answer with 'yes (definitely)' or 'yes (moderately)' or 'yes (barely)' or 'no'."
    )
    results = {filename: sambanova_agent.process_text(text, samba_key, prompt) for filename, text in texts.items()}

    # Consolidate results and refine with the manager agent
    final_result = consolidate_results_and_refine(results, topic, sambanova_agent, texts, samba_key)

    # Print categorized results
    if final_result:
        print("Categorized Results:")
        for category, files in final_result['categorized_results'].items():
            print(f"{category.capitalize()}: {', '.join(files) if files else 'None'}")

        print("\nDetailed Results:")
        for filename, refined_result in final_result['detailed_results'].items():
            print(f"File: {filename}")
            print(f" - {refined_result}")
    else:
        print("No relevant results found.")

if __name__ == "__main__":
    main()
        
    # Audio-to-text stuff

    # transcript_client = OpenAI(api_key=oai_key)

    # audio_file= open("sample.mp3", "rb")
    # transcription = transcript_client.audio.transcriptions.create(
    #   model="whisper-1", 
    #   file=audio_file
    # )
    # print(transcription.text)
