from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import pipeline

app = FastAPI()

class SummarizeRequest(BaseModel):
    text: str

# Load Falconsai/text_summarization model pipeline for summarization
summarizer = pipeline("summarization", model="Falconsai/text_summarization")

@app.get("/")
def root():
    return {"message": "API is working"}

@app.post("/summarize")
def summarize(request: SummarizeRequest):
    input_text = request.text.strip()
    if not input_text:
        raise HTTPException(status_code=400, detail="Input text is empty")

    try:
        result = summarizer(input_text, max_length=150, min_length=40, do_sample=False)
        summary = result[0]['summary_text']
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Summarization failed: {str(e)}")

    return {"summary": summary}
