"""Module de collecte des métriques système."""
from __future__ import annotations

import platform
import subprocess
from datetime import datetime, timezone
from typing import Any

import psutil


class MetricsCollectionError(RuntimeError):
    """Erreur levée lorsqu'une métrique ne peut pas être collectée."""

def get_load_average():
    try:
        # Exécution de la commande uptime
        result = subprocess.run(["uptime"], capture_output=True, text=True, check=True)
        stdout = result.stdout
        
        # Exemple de chaîne : " 10:00:00 up 2 days, load average: 0.10, 0.20, 0.30\n"
        if "load average:" in stdout:
            # On récupère tout ce qui est après "load average:"
            load_part = stdout.split("load average:")[1].strip()
            # On sépare les 3 valeurs par les virgules
            loads = [float(x.strip()) for x in load_part.split(",")]
            
            return {
                "load_1m": loads[0],
                "load_5m": loads[1],
                "load_15m": loads[2],
            }
    except (FileNotFoundError, subprocess.CalledProcessError, IndexError, ValueError) as e:
        # LE TEST 2 EXIGE QUE L'ON LÈVE CETTE EXCEPTION PRÉCISE
        raise MetricsCollectionError(f"Échec de la collecte du load average: {e}")
        
    return {"load_1m": None, "load_5m": None, "load_15m": None}

def collect_system_metrics() -> dict[str, Any]:
    """Collecte les métriques CPU, RAM et la charge système."""
    try:
        memory = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=0.1)
        load_average = get_load_average()

        return {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "hostname": platform.node(),
            "cpu": {
                "percent": cpu_percent,
                "logical_cores": psutil.cpu_count(logical=True),
            },
            "memory": {
                "total_bytes": memory.total,
                "available_bytes": memory.available,
                "used_bytes": memory.used,
                "percent": memory.percent,
            },
            "system": load_average,
        }
    except MetricsCollectionError:
        raise
    except Exception as exc:
        raise MetricsCollectionError(
            f"Erreur pendant la collecte des métriques : {exc}"
        ) from exc
