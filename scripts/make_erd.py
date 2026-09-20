"""Generates a simple ERD diagram (images/erd.png) for the README."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES_DIR = os.path.join(PROJECT_ROOT, "images")
os.makedirs(IMAGES_DIR, exist_ok=True)

tables = {
    "plans":       ["plan_id (PK)", "plan_name", "monthly_price", "data_allowance_gb", "plan_type"],
    "stores":      ["store_id (PK)", "store_name", "city", "state", "region", "open_date"],
    "employees":   ["employee_id (PK)", "employee_name", "store_id (FK)", "role", "hire_date", "termination_date"],
    "customers":   ["customer_id (PK)", "customer_name", "state", "signup_date"],
    "transactions":["transaction_id (PK)", "store_id (FK)", "employee_id (FK)", "customer_id (FK)",
                     "plan_id (FK)", "transaction_date", "transaction_type", "status", "amount"],
}

positions = {
    "stores":       (0.05, 0.62),
    "employees":    (0.05, 0.10),
    "plans":        (0.72, 0.72),
    "customers":    (0.72, 0.08),
    "transactions": (0.38, 0.38),
}

box_w, row_h, pad = 0.24, 0.045, 0.02

fig, ax = plt.subplots(figsize=(12, 8))
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis("off")

box_geom = {}
for name, cols in tables.items():
    x, y = positions[name]
    h = row_h * (len(cols) + 1) + pad
    box_geom[name] = (x, y, box_w, h)

    header_color = "#2b6cb0" if name == "transactions" else "#4a5568"
    ax.add_patch(mpatches.FancyBboxPatch((x, y), box_w, h,
                 boxstyle="round,pad=0.006", linewidth=1.2,
                 edgecolor="#1a202c", facecolor="white", zorder=2))
    ax.add_patch(mpatches.FancyBboxPatch((x, y + h - row_h - pad/2), box_w, row_h + pad/2,
                 boxstyle="round,pad=0.006", linewidth=1.2,
                 edgecolor="#1a202c", facecolor=header_color, zorder=3))
    ax.text(x + box_w/2, y + h - row_h/2 - pad/4, name, ha="center", va="center",
            fontsize=12, fontweight="bold", color="white", zorder=4)

    for i, col in enumerate(cols):
        cy = y + h - row_h - pad/2 - row_h * (i + 1) + row_h/2
        weight = "bold" if "PK" in col else ("normal")
        color = "#c05621" if "FK" in col else "#1a202c"
        ax.text(x + 0.012, cy, col, ha="left", va="center", fontsize=9.5,
                fontweight=weight, color=color, zorder=4)

def connect(t1, t2, start_col_idx, label=""):
    x1, y1, w1, h1 = box_geom[t1]
    x2, y2, w2, h2 = box_geom[t2]
    p1 = (x1 + w1/2, y1 + h1/2)
    p2 = (x2 + w2/2, y2 + h2/2)
    arrow = FancyArrowPatch(p1, p2, arrowstyle="-|>", mutation_scale=14,
                             color="#718096", linewidth=1.3, zorder=1,
                             connectionstyle="arc3,rad=0.05")
    ax.add_patch(arrow)

for t in ["stores", "employees", "customers", "plans"]:
    connect(t, "transactions", 0)

ax.set_title("Telecom Retail Store Performance -- Entity Relationship Diagram",
             fontsize=14, fontweight="bold", pad=20)
plt.tight_layout()
out_path = os.path.join(IMAGES_DIR, "erd.png")
plt.savefig(out_path, dpi=160, bbox_inches="tight", facecolor="white")
print(f"wrote {out_path}")
