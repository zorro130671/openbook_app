import os

def create_file(path, content):
    full_path = os.path.join(os.getcwd(), path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"✅ File created: {path}")

if __name__ == "__main__":
    print("🧠 ZahGPT Dev Agent Ready.")
    while True:
        command = input(">>> ")
        if command.startswith("create_file"):
            # Format: create_file path|code_here
            try:
                _, payload = command.split(" ", 1)
                path, code = payload.split("|", 1)
                create_file(path.strip(), code.strip())
            except Exception as e:
                print(f"❌ Error: {e}")
        elif command in ["exit", "quit"]:
            break
