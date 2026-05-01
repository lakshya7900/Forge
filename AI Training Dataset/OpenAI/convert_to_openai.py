import json

def fix_file(input_path, output_path):
    fixed = 0
    skipped = 0
    total = 0

    with open(input_path, 'r') as f_in, open(output_path, 'w') as f_out:
        for line in f_in:
            line = line.strip()
            if not line:
                continue
            total += 1
            example = json.loads(line)
            messages = example.get("messages", [])

            while messages and messages[-1]["role"] == "user":
                messages.pop()

            if len(messages) < 3:
                skipped += 1
                continue

            example["messages"] = messages
            f_out.write(json.dumps(example) + "\n")
            fixed += 1

    print(f"{input_path}: {total} total → {fixed} written, {skipped} skipped")

for split in ["train", "val"]:
    fix_file(f"{split}.jsonl", f"{split}_fixed.jsonl")