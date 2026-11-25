"""Run the SQL analyses and export results (CSV) and charts (PNG) to reports/.

Prerequisite: `dbt build` and `dbt compile` have been run (see Makefile).
"""
from __future__ import annotations

import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import psycopg2

ROOT = Path(__file__).resolve().parents[1]
COMPILED = ROOT / "olist_dbt" / "target" / "compiled" / "olist_dbt" / "analyses"
OUT = ROOT / "reports"
FIG = OUT / "figures"

INK, MUTED, GRID, BLUE, RED, GREEN = "#1f2933", "#7b8794", "#e4e7eb", "#2563eb", "#dc2626", "#16a34a"


def connect():
    conn = psycopg2.connect(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5433"),
                            user=os.getenv("PGUSER", "olist"), password=os.getenv("PGPASSWORD", "olist"),
                            dbname=os.getenv("PGDATABASE", "olist"))
    conn.set_client_encoding("UTF8")
    return conn


def q(conn, sql: str) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(sql)
        cols = [c.name for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)


def style(ax, grid="y"):
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["left", "bottom"]].set_color(MUTED)
    ax.tick_params(colors=INK, labelsize=9)
    ax.grid(axis=grid, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def save(fig, name):
    fig.tight_layout()
    fig.savefig(FIG / name, dpi=150, bbox_inches="tight")
    plt.close(fig)


def main():
    FIG.mkdir(parents=True, exist_ok=True)
    conn = connect()

    # 1. Ad-hoc analyses (compiled by dbt from olist_dbt/analyses)
    for sql_file in sorted(COMPILED.glob("*.sql")):
        df = q(conn, sql_file.read_text())
        df.to_csv(OUT / f"{sql_file.stem}.csv", index=False)
        print(f"{sql_file.stem}: {len(df)} rows")

    # 2. Charts from the marts
    kpi = q(conn, "select * from analytics.mart_monthly_kpis order by month").astype({"gmv": float, "late_delivery_rate": float, "avg_review_score": float})
    kpi["month"] = pd.to_datetime(kpi["month"])
    kpi.to_csv(OUT / "monthly_kpis.csv", index=False)
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 5.6), sharex=True, gridspec_kw={"height_ratios": [3, 2]})
    ax1.bar(kpi["month"], kpi["gmv"] / 1e6, width=20, color=BLUE)
    ax1.set_ylabel("GMV (M R$)")
    ax1.set_title("GMV mensuel et taux de livraison en retard (2017-2018)", loc="left", fontsize=11, color=INK)
    ax2.plot(kpi["month"], kpi["late_delivery_rate"] * 100, "o-", color=RED, ms=4)
    ax2.set_ylabel("% livré en retard")
    for m, label in [("2017-11-01", "Black Friday"), ("2018-03-01", "fév.-mars 2018")]:
        r = kpi[kpi["month"] == m].iloc[0]
        ax2.annotate(label, (r["month"], r["late_delivery_rate"] * 100), xytext=(8, 0),
                     textcoords="offset points", fontsize=8, color=RED, va="center")
    style(ax1)
    style(ax2)
    save(fig, "01_monthly_gmv_late_rate.png")

    deliv = q(conn, "select * from analytics.mart_delivery_performance where customer_state = 'TOTAL' and delay_bucket <> 'ALL' order by delay_bucket")
    fig, ax = plt.subplots(figsize=(9, 3.6))
    labels = [b.split(". ", 1)[1] for b in deliv["delay_bucket"]]
    colors = [GREEN, GREEN, "#f59e0b", RED, "#991b1b"]
    bars = ax.bar(labels, deliv["avg_review_score"].astype(float), color=colors)
    for b, n, bad in zip(bars, deliv["orders"], deliv["bad_review_rate"].astype(float)):
        ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 0.05, f"{b.get_height():.2f}\n{bad:.0%} d'avis ≤ 2",
                ha="center", va="bottom", fontsize=8, color=INK)
    ax.set_ylim(0, 5.4)
    ax.set_ylabel("note moyenne (/5)")
    ax.set_title("La note client s'effondre dès que la livraison dépasse la date promise", loc="left", fontsize=11, color=INK)
    style(ax)
    save(fig, "02_review_by_delay.png")

    coh = q(conn, "select cohort_month, months_since_first, retention_rate from analytics.mart_cohort_retention where months_since_first between 1 and 12")
    pivot = coh.pivot(index="cohort_month", columns="months_since_first", values="retention_rate").astype(float) * 100
    pivot.index = pd.to_datetime(pivot.index).strftime("%Y-%m")
    fig, ax = plt.subplots(figsize=(10, 5.2))
    im = ax.imshow(pivot.values, cmap="Blues", aspect="auto", vmin=0, vmax=1)
    for (i, j), v in np.ndenumerate(pivot.values):
        if not np.isnan(v):
            ax.text(j, i, f"{v:.1f}", ha="center", va="center", fontsize=7, color=INK if v < 0.6 else "white")
    ax.set_xticks(range(pivot.shape[1]), [f"M+{c}" for c in pivot.columns])
    ax.set_yticks(range(pivot.shape[0]), pivot.index)
    ax.tick_params(labelsize=8)
    ax.set_title("Rétention par cohorte d'acquisition (% de la cohorte qui recommande au mois M+n)",
                 loc="left", fontsize=11, color=INK)
    fig.colorbar(im, ax=ax, pad=0.01).set_label("%", fontsize=9)
    save(fig, "03_cohort_retention.png")

    funnel = q(conn, "select * from analytics.mart_seller_acquisition_funnel where origin <> 'TOTAL' and mqls >= 100 order by mql_to_deal_rate desc")
    funnel.to_csv(OUT / "seller_acquisition_funnel.csv", index=False)
    fig, ax = plt.subplots(figsize=(9, 3.8))
    ax.barh(funnel["origin"], funnel["mql_to_deal_rate"].astype(float) * 100, color=BLUE)
    for i, r in funnel.reset_index().iterrows():
        ax.text(float(r.mql_to_deal_rate) * 100 + 0.2, i, f"{r.deals_won}/{r.mqls} leads", va="center", fontsize=8, color=MUTED)
    ax.invert_yaxis()
    ax.set_xlabel("taux de conversion lead → vendeur signé (%)")
    ax.set_title("Acquisition de vendeurs : conversion par canal (canaux ≥ 100 leads)", loc="left", fontsize=11, color=INK)
    style(ax, grid="x")
    save(fig, "04_seller_funnel.png")

    cat = q(conn, "select category, revenue, growth_yoy from analytics.mart_category_performance order by revenue desc limit 12").astype({"revenue": float, "growth_yoy": float})
    cat.to_csv(OUT / "top_categories.csv", index=False)
    platform = float(q(conn, """
        select sum(order_value) filter (where purchased_at >= '2018-01-01' and purchased_at < '2018-09-01')
             / sum(order_value) filter (where purchased_at >= '2017-01-01' and purchased_at < '2017-09-01') - 1 as g
        from core.fct_orders where order_status not in ('canceled', 'unavailable')""")["g"].iloc[0])
    fig, ax = plt.subplots(figsize=(9, 4.4))
    # A category "wins" only if it grows faster than the marketplace itself.
    colors = [GREEN if g >= platform else RED for g in cat["growth_yoy"]]
    ax.barh(cat["category"], cat["revenue"] / 1e3, color=BLUE)
    for i, r in cat.iterrows():
        ax.text(r.revenue / 1e3 + 15, i, f"{r.growth_yoy:+.0%}", va="center", fontsize=8, color=colors[i])
    ax.invert_yaxis()
    ax.set_xlabel("chiffre d'affaires produits 2017-2018 (k R$)")
    ax.set_title(f"Top 12 catégories. Croissance jan.-août 2018 vs 2017 : vert = plus vite que la plateforme ({platform:+.0%})",
                 loc="left", fontsize=10, color=INK)
    style(ax, grid="x")
    save(fig, "05_top_categories.png")

    heat = pd.read_csv(OUT / "q03_orders_by_weekday_hour.csv").pivot(index="iso_weekday", columns="hour", values="orders")
    fig, ax = plt.subplots(figsize=(10, 3.2))
    ax.imshow(heat.values, cmap="Blues", aspect="auto")
    ax.set_yticks(range(7), ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"])
    ax.set_xticks(range(0, 24, 2), [f"{h}h" for h in range(0, 24, 2)])
    ax.tick_params(labelsize=8)
    ax.set_title("Commandes par jour et heure : pic en semaine de 10 h à 22 h, creux le samedi",
                 loc="left", fontsize=11, color=INK)
    save(fig, "06_weekday_hour.png")

    sellers = q(conn, "select revenue from analytics.mart_seller_scorecard order by revenue desc").astype(float)
    cum = sellers["revenue"].cumsum() / sellers["revenue"].sum() * 100
    x = np.arange(1, len(cum) + 1) / len(cum) * 100
    fig, ax = plt.subplots(figsize=(7, 3.8))
    ax.plot(x, cum, color=BLUE, linewidth=2)
    ax.plot([0, 100], [0, 100], color=MUTED, linestyle="--", linewidth=1)
    k80 = x[np.argmax(cum.values >= 80)]
    ax.axhline(80, color=MUTED, linestyle=":", linewidth=1)
    ax.axvline(k80, color=MUTED, linestyle=":", linewidth=1)
    ax.text(k80 + 2, 40, f"{k80:.0f} % des vendeurs\n= 80 % du CA", fontsize=9, color=INK)
    ax.set_xlabel("% des vendeurs (classés par CA)")
    ax.set_ylabel("% cumulé du CA")
    ax.set_title("Concentration du chiffre d'affaires (courbe de Pareto)", loc="left", fontsize=11, color=INK)
    style(ax)
    save(fig, "07_seller_pareto.png")

    print(f"Figures written to {FIG}")


if __name__ == "__main__":
    main()
