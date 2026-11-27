"""Produce review and texture budgets from one verified in-memory scan.

Run while the Factory holds its production locks. Never trust a previous
review index as a replacement for verification of current asset bytes.
"""
import argparse
from pathlib import Path

from budgets import report_from_rows
from factory_ledger import atomic
from review_queue import build_report, scan


def run(raw, refined, size, review_output, budget_output):
    root = refined.resolve()
    if (review_output.resolve().parent != root
            or budget_output.resolve().parent != root
            or review_output.resolve() == budget_output.resolve()
            or review_output.is_symlink() or budget_output.is_symlink()):
        raise ValueError("Distinct report paths inside refinement root required")
    rows = scan(raw.resolve(), root, size)
    review = build_report(rows, size)
    # Preserve invalid-source diagnostics and fail before issuing a new budget.
    if any(row["status"] == "invalid-source" for row in rows):
        atomic(review_output, review)
        print("Review contains invalid sources; budget report not updated")
        return 1
    budget = report_from_rows(rows)
    atomic(review_output, review)
    atomic(budget_output, budget)
    print("Review candidates:", review["ready_for_review"], "index:", review_output)
    print("Texture budget records:", len(budget["rows"]), "index:", budget_output)
    return 0


def main():
    parser = argparse.ArgumentParser()
    for key in ("raw", "refined", "review-output", "budget-output"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    return run(args.raw, args.refined, args.size, args.review_output, args.budget_output)


if __name__ == "__main__":
    raise SystemExit(main())
