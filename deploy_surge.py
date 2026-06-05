import subprocess
import time
import sys
import os

print("Starting surge deployment...")

# Start surge
p = subprocess.Popen(['npx.cmd', 'surge', './build/web', 'geovision-web-app.surge.sh'], 
                     stdin=subprocess.PIPE, 
                     stdout=subprocess.PIPE, 
                     stderr=subprocess.STDOUT, 
                     text=True, 
                     bufsize=1,
                     encoding='utf-8',
                     errors='ignore',
                     universal_newlines=True)

def read_until(process, target, timeout=30):
    start_time = time.time()
    output = ""
    while True:
        if time.time() - start_time > timeout:
            return output
        char = process.stdout.read(1)
        if not char:
            break
        output += char
        if target in output:
            return output
    return output

output = read_until(p, "email:", timeout=60)
if "email:" in output:
    print("\nSending email...")
    p.stdin.write("marc.pedrin.geovision@gmail.com\n")
    p.stdin.flush()

output = read_until(p, "password:", timeout=30)
if "password:" in output:
    print("\nSending password...")
    p.stdin.write("GeoVision2025!\n")
    p.stdin.flush()

# Read the rest of the output
while True:
    char = p.stdout.read(1)
    if not char:
        break

p.wait()
print(f"\nProcess exited with code {p.returncode}")
