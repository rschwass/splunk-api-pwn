import sys
import json

def main():
    response = {"status": "success", "message": "execute.py is working"}
    print(json.dumps(response))  # Output JSON response

if __name__ == "__main__":
    main()
