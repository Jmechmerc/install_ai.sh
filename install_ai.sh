#!/bin/bash

echo "🔹 Starting AI Installation & Setup..."

# 1️⃣ Check Internet Connection
echo "🔹 Checking Internet Connection..."
if ! ping -c 1 google.com &> /dev/null; then
    echo "❌ No internet connection detected! Please check your network."
    exit 1
fi
echo "✅ Internet connection is active!"

# 2️⃣ Update & Upgrade Termux
echo "🔹 Updating Termux Packages..."
pkg update -y && pkg upgrade -y

# 3️⃣ Install Dependencies
echo "🔹 Installing Required Packages..."
pkg install -y python wget curl git termux-api aria2 cronie
pip install --upgrade fastapi uvicorn requests google-generativeai ollama || {
    echo "❌ Failed to install Python dependencies. Retrying..."
    pip install fastapi uvicorn requests google-generativeai ollama
}

# 4️⃣ Download AI Model
MODEL_URL="https://huggingface.co/TheBloke/Mistral-7B-GGUF/resolve/main/mistral-7b.Q5_K.gguf"
MODEL_PATH="$HOME/mistral-7b.Q5_K.gguf"

if [ ! -f "$MODEL_PATH" ]; then
    echo "🔹 Downloading AI Model..."
    aria2c -x 16 -s 16 -j 16 "$MODEL_URL" -d "$HOME" -o "mistral-7b.Q5_K.gguf" || wget -O "$MODEL_PATH" "$MODEL_URL"
    if [ $? -ne 0 ]; then
        echo "❌ AI Model download failed! Check your connection or storage."
        exit 1
    fi
    echo "✅ AI Model Downloaded Successfully!"
else
    echo "✅ AI Model Already Exists, Skipping Download..."
fi

# 5️⃣ Set up Auto-Start on Boot
echo "🔹 Configuring Auto-Start on Boot..."
(crontab -l 2>/dev/null; echo "@reboot cd $HOME && python3 ~/ai_setup.py") | crontab -
termux-wake-lock
echo "✅ Auto-Start Configured!"

# 6️⃣ Create AI Setup Python Script
echo "🔹 Creating AI Setup Python Script..."
cat > $HOME/ai_setup.py <<'EOPYTHON'
#!/usr/bin/env python3

import os
import subprocess
import google.generativeai as genai

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

MODEL_PATH = os.path.expanduser("~/mistral-7b.Q5_K.gguf")

def detect_hardware():
    print("\n[✔] Detecting Hardware Capabilities...")
    cpu_info = subprocess.getoutput("cat /proc/cpuinfo")
    if "neon" in cpu_info or "avx2" in cpu_info:
        print("[✔] Optimized CPU detected.")
    else:
        print("[⚠] Limited CPU detected. Expect slower performance.")

def start_ai_server():
    print("\n[✔] Starting AI API Server...")
    try:
        subprocess.Popen("ollama run tinymistral", shell=True)
        print("\n[✔] AI Server is Running!")
    except Exception as e:
        print(f"\n[✖] Failed to start AI server: {e}")

def query_ai():
    print("\n🧠 Choose AI Mode:")
    print("1️⃣ Local AI (TinyMistral)")
    print("2️⃣ Cloud AI (Gemini)")
    
    choice = input("\n🔹 Enter choice (1 or 2): ")
    
    if choice not in ["1", "2"]:
        print("\n[✖] Invalid choice! Please enter 1 or 2.")
        return

    prompt = input("\n📝 Enter Your Question: ")

    try:
        if choice == "1":
            response = subprocess.getoutput(f"ollama run tinymistral \"{prompt}\"")
        elif choice == "2":
            response = query_gemini(prompt)
    except Exception as e:
        response = f"❌ Error processing request: {e}"
    
    print("\n🤖 AI Response:", response)

def query_gemini(prompt):
    try:
        model = genai.GenerativeModel("gemini-pro")
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"❌ Error with Gemini API: {e}"

if __name__ == "__main__":
    detect_hardware()
EOPYTHON

chmod +x $HOME/ai_setup.py
echo "✅ AI Setup Completed! Run the AI Control Panel with:"
echo "➡ python3 ~/ai_setup.py"
EOF

chmod +x install_ai.sh
bash install_ai.sh
