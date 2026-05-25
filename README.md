# Technologie Chmurowe - Zadanie 2

## Cel zadania

Celem zadania było opracowanie pipeline w GitHub Actions, który buduje obraz kontenera na podstawie pliku `Dockerfile` i kodu źródłowego aplikacji, wykonuje test CVE, a następnie publikuje obraz do GitHub Container Registry (`ghcr.io`).

Obraz jest wysyłany do GHCR tylko wtedy, gdy skan CVE nie wykryje podatności o poziomie `HIGH` lub `CRITICAL`.

## Struktura repozytorium

```text
.
├── .github/
│   └── workflows/
│       └── zadanie2.yml
├── Dockerfile
├── README.md
└── src/
    └── index.html
