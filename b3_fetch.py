#!/usr/bin/env python3
"""
B3 Data Fetcher for Omarchy Plugin
Fetches quotes, historical points, and calculates period variation.
"""

from concurrent.futures import ThreadPoolExecutor
import argparse
import json
import os
import sys
import time
import urllib.request

RANGE_INTERVALS = {
    "1d": "5m",
    "5d": "15m",
    "1mo": "1d",
    "3mo": "1d",
    "6mo": "1d",
    "ytd": "1d",
    "1y": "1d",
}

CACHE_DIR = os.path.expanduser("~/.cache/omarchy/b3-tracker")
CONFIG_PATH = os.path.expanduser("~/.config/omarchy/b3-tracker.json")
CACHE_TTL = 180  # 3 minutes

DEFAULT_CATEGORIES = {
    "Watchlist": [
        {"symbol": "CMIG3", "name": "Cemig"},
        {"symbol": "CPFE3", "name": "CPFL Energia"},
        {"symbol": "CXSE3", "name": "Caixa Seguridade"},
        {"symbol": "SAPR3", "name": "Sanepar ON"},
        {"symbol": "SAPR4", "name": "Sanepar PN"},
    ],
    "Carteira Ações": [
        {"symbol": "ALUP3", "name": "Alupar ON"},
        {"symbol": "ALUP4", "name": "Alupar PN"},
        {"symbol": "BBAS3", "name": "Banco do Brasil"},
        {"symbol": "BBSE3", "name": "BB Seguridade"},
        {"symbol": "ITSA4", "name": "Itaúsa"},
        {"symbol": "KLBN4", "name": "Klabin"},
        {"symbol": "SAUD3", "name": "Bradsaude"},
        {"symbol": "TIMS3", "name": "TIM"},
    ],
    "FIIs": [
        {"symbol": "GARE11", "name": "Guardian Real Estate"},
        {"symbol": "GGRC11", "name": "GGR Covepi"},
        {"symbol": "HGLG11", "name": "Patria Log FII"},
    ],
}


def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"defaultWindow": "1mo", "categories": DEFAULT_CATEGORIES}


def save_config(config):
    real_path = os.path.realpath(CONFIG_PATH)
    os.makedirs(os.path.dirname(real_path), exist_ok=True)
    with open(real_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if os.path.exists(CACHE_DIR):
        for fname in os.listdir(CACHE_DIR):
            if fname.startswith("cache_"):
                try:
                    os.remove(os.path.join(CACHE_DIR, fname))
                except Exception:
                    pass


def add_asset(symbol: str, name: str, category: str):
    symbol = symbol.strip().upper()
    if symbol.endswith(".SA"):
        symbol = symbol[:-3]
    if not symbol:
        return False
    name = name.strip() if name else symbol
    category = category.strip() if category else "Watchlist"

    config = load_config()
    if "categories" not in config:
        config["categories"] = {}
    if category not in config["categories"]:
        config["categories"][category] = []

    existing = False
    for item in config["categories"][category]:
        if item.get("symbol", "").upper() == symbol:
            item["name"] = name
            existing = True
            break
    if not existing:
        config["categories"][category].append({"symbol": symbol, "name": name})

    save_config(config)
    return True


def remove_asset(symbol: str, category: str = None):
    symbol = symbol.strip().upper()
    if symbol.endswith(".SA"):
        symbol = symbol[:-3]
    if not symbol:
        return False

    config = load_config()
    categories = config.get("categories", {})
    if category and category in categories:
        categories[category] = [i for i in categories[category] if i.get("symbol", "").upper() != symbol]
    else:
        for cat in categories:
            categories[cat] = [i for i in categories[cat] if i.get("symbol", "").upper() != symbol]

    save_config(config)
    return True


def add_category(category: str):
    category = category.strip()
    if not category:
        return False
    config = load_config()
    if "categories" not in config:
        config["categories"] = {}
    if category not in config["categories"]:
        config["categories"][category] = []
        save_config(config)
    return True


def remove_category(category: str):
    category = category.strip()
    if not category:
        return False
    config = load_config()
    if "categories" in config and category in config["categories"]:
        del config["categories"][category]
        save_config(config)
    return True


def fetch_symbol(symbol: str, name: str, category: str, range_str: str, interval: str):
    sa_symbol = symbol if symbol.endswith(".SA") else f"{symbol}.SA"
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{sa_symbol}?range={range_str}&interval={interval}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            raw = json.loads(res.read())
            chart_res = raw.get("chart", {}).get("result", [])
            if not chart_res:
                return None
            data = chart_res[0]
            meta = data.get("meta", {})
            price = meta.get("regularMarketPrice")

            quote_data = data.get("indicators", {}).get("quote", [{}])[0]
            closes = [c for c in quote_data.get("close", []) if c is not None]

            if not closes and price is not None:
                closes = [price]
            elif not closes:
                return None

            if price is None and closes:
                price = closes[-1]

            start_price = closes[0]
            current_price = closes[-1] if price is None else price
            change = current_price - start_price
            change_pct = ((current_price - start_price) / start_price) * 100 if start_price else 0.0

            # Downsample points for sparkline if too many
            max_points = 30
            if len(closes) > max_points:
                step = len(closes) / max_points
                sampled = [round(closes[int(i * step)], 2) for i in range(max_points - 1)]
                sampled.append(round(current_price, 2))
            else:
                sampled = [round(c, 2) for c in closes]

            return {
                "symbol": symbol,
                "name": name,
                "category": category,
                "price": round(current_price, 2),
                "startPrice": round(start_price, 2),
                "change": round(change, 2),
                "changePercent": round(change_pct, 2),
                "points": sampled,
            }
    except Exception as e:
        return {
            "symbol": symbol,
            "name": name,
            "category": category,
            "price": 0.0,
            "startPrice": 0.0,
            "change": 0.0,
            "changePercent": 0.0,
            "points": [],
            "error": str(e),
        }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--window", default="1mo")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--add-asset", action="store_true")
    parser.add_argument("--remove-asset", action="store_true")
    parser.add_argument("--add-category", action="store_true")
    parser.add_argument("--remove-category", action="store_true")
    parser.add_argument("--symbol", default="")
    parser.add_argument("--name", default="")
    parser.add_argument("--category", default="")
    args = parser.parse_args()

    if args.add_asset:
        success = add_asset(args.symbol, args.name, args.category)
        print(json.dumps({"success": success}))
        return

    if args.remove_asset:
        success = remove_asset(args.symbol, args.category if args.category else None)
        print(json.dumps({"success": success}))
        return

    if args.add_category:
        success = add_category(args.category)
        print(json.dumps({"success": success}))
        return

    if args.remove_category:
        success = remove_category(args.category)
        print(json.dumps({"success": success}))
        return

    range_str = args.window.lower()
    if range_str not in RANGE_INTERVALS:
        range_str = "1mo"
    interval = RANGE_INTERVALS[range_str]

    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_file = os.path.join(CACHE_DIR, f"cache_{range_str}.json")

    # Check cache
    if not args.force and os.path.exists(cache_file):
        try:
            mtime = os.path.getmtime(cache_file)
            if time.time() - mtime < CACHE_TTL:
                with open(cache_file, "r", encoding="utf-8") as f:
                    print(f.read())
                    return
        except Exception:
            pass

    config = load_config()
    categories = config.get("categories", DEFAULT_CATEGORIES)

    tasks = []
    category_map = {}
    for cat_name, items in categories.items():
        category_map[cat_name] = [item["symbol"] for item in items]
        for item in items:
            tasks.append((item["symbol"], item.get("name", item["symbol"]), cat_name))

    results = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [
            executor.submit(fetch_symbol, sym, name, cat, range_str, interval)
            for sym, name, cat in tasks
        ]
        for f in futures:
            res = f.result()
            if res:
                results.append(res)

    # Sort default by performance descending (best performers first)
    results.sort(key=lambda x: x.get("changePercent", 0.0), reverse=True)

    output = {
        "window": range_str,
        "updatedAt": time.strftime("%H:%M:%S"),
        "timestamp": int(time.time()),
        "categories": list(categories.keys()),
        "categoryMap": category_map,
        "rawCategories": categories,
        "assets": results,
    }

    serialized = json.dumps(output, ensure_ascii=False)
    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            f.write(serialized)
    except Exception:
        pass

    print(serialized)


if __name__ == "__main__":
    main()
