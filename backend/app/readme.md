
# to run 

```
pip install -r backend/requirements.txt
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

# quick check
curl http://localhost:8000/health/

