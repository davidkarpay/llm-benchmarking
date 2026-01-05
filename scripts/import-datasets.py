#!/usr/bin/env python3
"""
Import public benchmark datasets and convert to our test suite JSON schema.

Usage:
    python scripts/import-datasets.py --dataset gsm8k --output test-suites/reasoning/
    python scripts/import-datasets.py --dataset humaneval --output test-suites/code/
    python scripts/import-datasets.py --dataset mmlu --output test-suites/knowledge/ --limit 100
    python scripts/import-datasets.py --all --limit 100

Supported datasets:
    - gsm8k: Grade School Math 8K (1,319 test problems)
    - humaneval: OpenAI HumanEval (164 code problems)
    - mmlu: MMLU-Pro multi-subject knowledge (12,000 questions)
    - arc: AI2 Reasoning Challenge (7,787 questions)
"""

import argparse
import json
import os
import re
from pathlib import Path


def extract_gsm8k_answer(answer_text):
    """Extract final numeric answer from GSM8K format (after ####)."""
    if "####" in answer_text:
        final = answer_text.split("####")[-1].strip()
        # Clean up the number
        final = re.sub(r'[,$]', '', final)
        return final
    return answer_text.strip()


def extract_expected_keywords(answer_text, dataset_type):
    """Extract keywords that should appear in a correct response."""
    keywords = []

    if dataset_type == "gsm8k":
        # For math, expect the final answer
        final_answer = extract_gsm8k_answer(answer_text)
        if final_answer:
            keywords.append(final_answer)
    elif dataset_type == "humaneval":
        # For code, expect function definition keywords
        keywords.extend(["def", "return"])
    elif dataset_type == "mmlu":
        # For multiple choice, the answer letter
        keywords.append(answer_text)
    elif dataset_type == "arc":
        keywords.append(answer_text)

    return keywords


def convert_gsm8k(ds, output_dir, limit=None, split="test"):
    """Convert GSM8K dataset to our schema."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cases = []
    data = ds[split]
    total = min(len(data), limit) if limit else len(data)

    for i, item in enumerate(data):
        if limit and i >= limit:
            break

        question = item["question"]
        answer = item["answer"]
        final_answer = extract_gsm8k_answer(answer)

        case = {
            "id": f"gsm8k-{i+1:04d}",
            "prompt": question,
            "expected_specialist": "reasoning-specialist",
            "expected_response_contains": [final_answer] if final_answer else [],
            "ground_truth": final_answer,
            "reference_answer": answer,
            "difficulty": "medium",
            "tags": ["math", "word-problem", "arithmetic"]
        }
        cases.append(case)

    # Split into files of 100 each
    chunk_size = 100
    for chunk_idx in range(0, len(cases), chunk_size):
        chunk = cases[chunk_idx:chunk_idx + chunk_size]
        file_num = (chunk_idx // chunk_size) + 1

        suite = {
            "domain": "general",
            "subdomain": "reasoning",
            "version": "1.0",
            "description": f"GSM8K Grade School Math problems (batch {file_num})",
            "metadata": {
                "source": "openai/gsm8k",
                "split": split
            },
            "cases": chunk
        }

        output_file = output_dir / f"gsm8k-{file_num:03d}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(suite, f, indent=2, ensure_ascii=False)

        print(f"  Wrote {len(chunk)} tests to {output_file}")

    return len(cases)


def convert_humaneval(ds, output_dir, limit=None):
    """Convert HumanEval dataset to our schema."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cases = []
    data = ds["test"]
    total = min(len(data), limit) if limit else len(data)

    for i, item in enumerate(data):
        if limit and i >= limit:
            break

        # HumanEval provides a function signature + docstring as prompt
        prompt = item["prompt"]
        canonical = item["canonical_solution"]
        entry_point = item["entry_point"]

        # Create a cleaner prompt for code generation
        clean_prompt = f"Complete this Python function:\n\n{prompt}"

        case = {
            "id": f"humaneval-{item['task_id'].replace('/', '-')}",
            "prompt": clean_prompt,
            "expected_specialist": "code-specialist",
            "expected_response_contains": ["def", "return"],
            "expected_response_regex": r"def\s+\w+.*:",
            "ground_truth": canonical.strip(),
            "reference_answer": canonical,
            "difficulty": "medium",
            "tags": ["python", "code-generation", "function-completion"]
        }
        cases.append(case)

    suite = {
        "domain": "general",
        "subdomain": "code",
        "version": "1.0",
        "description": "OpenAI HumanEval Python code completion problems",
        "metadata": {
            "source": "openai/openai_humaneval",
            "total_problems": 164
        },
        "cases": cases
    }

    output_file = output_dir / "humaneval.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(suite, f, indent=2, ensure_ascii=False)

    print(f"  Wrote {len(cases)} tests to {output_file}")
    return len(cases)


def convert_mmlu(ds, output_dir, limit=None, subjects=None, limit_per_subject=50):
    """Convert MMLU-Pro dataset to our schema, organized by subject.

    Args:
        limit: Total items to process (applied during iteration)
        limit_per_subject: Max items per subject category (default 50)
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Map MMLU subjects to our specialists
    subject_to_specialist = {
        "math": "reasoning-specialist",
        "physics": "reasoning-specialist",
        "chemistry": "knowledge-specialist",
        "biology": "knowledge-specialist",
        "computer science": "code-specialist",
        "engineering": "reasoning-specialist",
        "economics": "knowledge-specialist",
        "business": "knowledge-specialist",
        "psychology": "knowledge-specialist",
        "law": "knowledge-specialist",
        "health": "knowledge-specialist",
        "history": "knowledge-specialist",
        "philosophy": "knowledge-specialist",
        "other": "knowledge-specialist"
    }

    # Group by subject
    by_subject = {}
    subject_counts = {}
    data = ds["test"]

    for i, item in enumerate(data):
        if limit and i >= limit:
            break

        subject = item.get("category", "other").lower()
        if subjects and subject not in subjects:
            continue

        # Initialize counters
        if subject not in by_subject:
            by_subject[subject] = []
            subject_counts[subject] = 0

        # Skip if this subject is already at limit
        if limit_per_subject and subject_counts[subject] >= limit_per_subject:
            continue

        subject_counts[subject] += 1

        question = item["question"]
        options = item["options"]
        answer_idx = item["answer_index"] if "answer_index" in item else item.get("answer", 0)

        # Format as multiple choice
        options_text = "\n".join([f"{chr(65+j)}. {opt}" for j, opt in enumerate(options)])
        full_prompt = f"{question}\n\n{options_text}\n\nAnswer with the letter of the correct option."

        # Get correct answer letter
        if isinstance(answer_idx, int):
            correct_letter = chr(65 + answer_idx)
        else:
            correct_letter = str(answer_idx).upper()

        case = {
            "id": f"mmlu-{subject.replace(' ', '-')}-{len(by_subject[subject])+1:04d}",
            "prompt": full_prompt,
            "expected_specialist": subject_to_specialist.get(subject, "knowledge-specialist"),
            "expected_response_contains": [correct_letter],
            "ground_truth": correct_letter,
            "difficulty": "hard",
            "tags": ["multiple-choice", "knowledge", subject.replace(" ", "-")]
        }
        by_subject[subject].append(case)

    total = 0
    for subject, cases in by_subject.items():
        if not cases:
            continue

        suite = {
            "domain": "general",
            "subdomain": "knowledge",
            "version": "1.0",
            "description": f"MMLU-Pro {subject.title()} questions",
            "metadata": {
                "source": "TIGER-Lab/MMLU-Pro",
                "subject": subject
            },
            "cases": cases
        }

        safe_name = subject.replace(" ", "-").replace("/", "-")
        output_file = output_dir / f"mmlu-{safe_name}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(suite, f, indent=2, ensure_ascii=False)

        print(f"  Wrote {len(cases)} {subject} tests to {output_file}")
        total += len(cases)

    return total


def convert_arc(ds, output_dir, limit=None, split="test"):
    """Convert ARC dataset to our schema."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cases = []
    data = ds[split]

    for i, item in enumerate(data):
        if limit and i >= limit:
            break

        question = item["question"]
        choices = item["choices"]
        answer_key = item["answerKey"]

        # Format choices
        labels = choices["label"]
        texts = choices["text"]
        options_text = "\n".join([f"{lbl}. {txt}" for lbl, txt in zip(labels, texts)])
        full_prompt = f"{question}\n\n{options_text}\n\nAnswer with the letter of the correct option."

        case = {
            "id": f"arc-{i+1:04d}",
            "prompt": full_prompt,
            "expected_specialist": "reasoning-specialist",
            "expected_response_contains": [answer_key],
            "ground_truth": answer_key,
            "difficulty": "medium",
            "tags": ["multiple-choice", "science", "reasoning"]
        }
        cases.append(case)

    # Split into files of 100 each
    chunk_size = 100
    for chunk_idx in range(0, len(cases), chunk_size):
        chunk = cases[chunk_idx:chunk_idx + chunk_size]
        file_num = (chunk_idx // chunk_size) + 1

        suite = {
            "domain": "general",
            "subdomain": "reasoning",
            "version": "1.0",
            "description": f"ARC Science Reasoning questions (batch {file_num})",
            "metadata": {
                "source": "allenai/ai2_arc",
                "split": split
            },
            "cases": chunk
        }

        output_file = output_dir / f"arc-{file_num:03d}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(suite, f, indent=2, ensure_ascii=False)

        print(f"  Wrote {len(chunk)} tests to {output_file}")

    return len(cases)


def main():
    parser = argparse.ArgumentParser(description="Import public benchmark datasets")
    parser.add_argument("--dataset", choices=["gsm8k", "humaneval", "mmlu", "arc", "all"],
                       help="Dataset to import")
    parser.add_argument("--output", type=str, default="test-suites",
                       help="Output directory for test suites")
    parser.add_argument("--limit", type=int, default=None,
                       help="Limit number of tests to import (useful for testing)")
    parser.add_argument("--all", action="store_true",
                       help="Import all supported datasets")

    args = parser.parse_args()

    if not args.dataset and not args.all:
        parser.print_help()
        return

    # Import datasets library here to avoid slow import on --help
    from datasets import load_dataset

    datasets_to_import = []
    if args.all or args.dataset == "all":
        datasets_to_import = ["gsm8k", "humaneval", "mmlu", "arc"]
    else:
        datasets_to_import = [args.dataset]

    total_imported = 0
    base_output = Path(args.output)

    for ds_name in datasets_to_import:
        print(f"\n{'='*60}")
        print(f"Importing {ds_name.upper()}...")
        print('='*60)

        try:
            if ds_name == "gsm8k":
                print("  Loading from HuggingFace: openai/gsm8k")
                ds = load_dataset("openai/gsm8k", "main")
                output_dir = base_output / "reasoning"
                count = convert_gsm8k(ds, output_dir, args.limit)

            elif ds_name == "humaneval":
                print("  Loading from HuggingFace: openai/openai_humaneval")
                ds = load_dataset("openai/openai_humaneval")
                output_dir = base_output / "code"
                count = convert_humaneval(ds, output_dir, args.limit)

            elif ds_name == "mmlu":
                print("  Loading from HuggingFace: TIGER-Lab/MMLU-Pro")
                ds = load_dataset("TIGER-Lab/MMLU-Pro")
                output_dir = base_output / "knowledge"
                count = convert_mmlu(ds, output_dir, args.limit)

            elif ds_name == "arc":
                print("  Loading from HuggingFace: allenai/ai2_arc (ARC-Challenge)")
                ds = load_dataset("allenai/ai2_arc", "ARC-Challenge")
                output_dir = base_output / "science"
                count = convert_arc(ds, output_dir, args.limit)

            total_imported += count
            print(f"  Total: {count} tests imported")

        except Exception as e:
            print(f"  ERROR: Failed to import {ds_name}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n{'='*60}")
    print(f"COMPLETE: {total_imported} total tests imported")
    print('='*60)


if __name__ == "__main__":
    main()
