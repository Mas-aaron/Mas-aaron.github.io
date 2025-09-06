# convert_utf16_to_utf8.py
import json

try:
    # Try reading as UTF-16 (most likely encoding)
    with open('whole.json', 'r', encoding='utf-16') as f:
        data = json.load(f)
    
    # Write back as UTF-8
    with open('whole_utf8.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print("Successfully converted whole.json from UTF-16 to UTF-8 as whole_utf8.json")
    
except UnicodeError:
    print("Not UTF-16, trying other encodings...")
    # Try other common encodings if UTF-16 fails
    encodings = ['utf-8-sig', 'utf-32', 'latin-1']
    
    for encoding in encodings:
        try:
            with open('whole.json', 'r', encoding=encoding) as f:
                data = json.load(f)
            
            with open('whole_utf8.json', 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            print(f"Successfully converted using {encoding} encoding")
            break
            
        except (UnicodeError, json.JSONDecodeError):
            continue
    else:
        print("Could not determine the file encoding. The file might be corrupted.")