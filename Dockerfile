# ==========================================
# 1. ÉTAPE COMMUNE DE BASE (Base Image Alpine)
# ==========================================
# À insérer sous l'étape 1 (ÉTAPE COMMUNE DE BASE)
FROM python:3.12-alpine AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# AJOUTEZ CETTE LIGNE ICI :
ENV PYTHONPATH=/app

WORKDIR /app


# ==========================================
# 2. ÉTAPE DE BUILD (Builder)
# ==========================================
FROM base AS builder

RUN apk add --no-cache build-base linux-headers

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ==========================================
# 3. ÉTAPE FINALE : CIBLE POUR L'API
# ==========================================
FROM base AS api

# curl est requis pour l'instruction HEALTHCHECK de l'API
RUN apk add --no-cache curl

# Création d'un utilisateur non-root (syntaxe Alpine avec adduser)
RUN adduser -D -u 10011 appuser && chown -R appuser:appuser /app
USER appuser

# Récupération des dépendances compilées
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Copie du code applicatif
COPY --chown=appuser:appuser app/ ./app/

EXPOSE 8000

# Vérification de l'état de santé
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "8000"]

# ==========================================
# 4. ÉTAPE FINALE : CIBLE POUR L'AGENT
# ==========================================
FROM base AS agent

# On installe le paquet 'procps' pour avoir la vraie commande uptime standard.
RUN apk add --no-cache procps

# Création d'un utilisateur non-root
RUN adduser -D -u 10012 appuser && chown -R appuser:appuser /app
USER appuser

# Récupération des dépendances
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Copie du code applicatif
COPY --chown=appuser:appuser app/ ./app/

CMD ["python", "app/agent.py"]
