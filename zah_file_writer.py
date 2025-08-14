import sys
import os
import base64

def create_or_update_file(file_path, content_b64):
    print(f"[ZAH FILE WRITER] Writing entire content to: {file_path}")
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    content = base64.b64decode(content_b64).decode('utf-8')
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[ZAH FILE WRITER] ✅ Full content replaced.")

def replace_in_file(file_path, old_b64, new_b64):
    if not os.path.exists(file_path):
        print(f"[ZAH FILE WRITER] ❌ File not found: {file_path}")
        return
    old = base64.b64decode(old_b64).decode('utf-8')
    new = base64.b64decode(new_b64).decode('utf-8')
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    updated_content = content.replace(old, new)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    print(f"[ZAH FILE WRITER] ✅ Replacement done.")

if __name__ == "__main__":
    print(f"[ZAH FILE WRITER] Args: {sys.argv}")
    print("[ZAH FILE WRITER] 🧠 ZahGPT triggered this via Open WebUI!")

    if len(sys.argv) == 4 and sys.argv[2] == '--replace-all':
        file_path = sys.argv[1]
        content_b64 = sys.argv[3]
        create_or_update_file(file_path, content_b64)
    elif len(sys.argv) == 5 and sys.argv[2] == '--replace':
        file_path = sys.argv[1]
        old_b64 = sys.argv[3]
        new_b64 = sys.argv[4]
        replace_in_file(file_path, old_b64, new_b64)
    else:
        print("[ZAH FILE WRITER] ❌ Invalid arguments.")
        print("Usage:")
        print("  python zah_file_writer.py <file_path> --replace-all <base64_content>")
        print("  python zah_file_writer.py <file_path> --replace <base64_old_text> <base64_new_text>")
