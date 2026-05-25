# Technologie Chmurowe - Zadanie 2

## Cel zadania

Celem zadania było przygotowanie pipeline w usłudze GitHub Actions, który:

- buduje obraz kontenera na podstawie pliku `Dockerfile` oraz kodu źródłowego aplikacji,
- wykonuje test CVE obrazu,
- publikuje finalny obraz do GitHub Container Registry (`ghcr.io`),
- wykorzystuje cache BuildKit przechowywany w DockerHub,
- buduje obraz dla dwóch architektur: `linux/amd64` oraz `linux/arm64`.

Finalny obraz jest wysyłany do GHCR tylko wtedy, gdy skan CVE nie wykryje podatności sklasyfikowanych jako `HIGH` albo `CRITICAL`.

Repozytorium projektu:

```text
https://github.com/jakubstepuch/tch-zadanie2
```

## Struktura repozytorium

```text
.
├── .github/
│   └── workflows/
│       └── zadanie2.yml
├── .gitignore
├── Dockerfile
├── README.md
└── src/
    └── index.html
```

## Przygotowanie katalogów projektu

Utworzono katalog projektu oraz katalogi na kod aplikacji i workflow GitHub Actions:

```bash
cd /home/kuba
mkdir -p tch-zadanie2
cd tch-zadanie2
mkdir -p src
mkdir -p .github/workflows
```

Sprawdzenie struktury:

```bash
pwd
find . -maxdepth 3 -print
```

Wynik:

```text
/home/kuba/tch-zadanie2
.
./.github
./.github/workflows
./src
```

## Kod aplikacji

Aplikacja jest prostą stroną HTML umieszczoną w pliku:

```text
src/index.html
```

Utworzenie pliku:

```bash
cat > src/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>Technologie Chmurowe - Zadanie 2</title>
</head>
<body>
    <h1>Technologie Chmurowe - Zadanie 2</h1>
    <p>Student: Jakub_Stepuch</p>
    <p>Obraz kontenera został zbudowany automatycznie przez GitHub Actions.</p>
    <p>Finalny obraz publikowany jest do GitHub Container Registry.</p>
</body>
</html>
EOF
```

Sprawdzenie zawartości:

```bash
cat src/index.html
```

Wynik:

```html
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>Technologie Chmurowe - Zadanie 2</title>
</head>
<body>
    <h1>Technologie Chmurowe - Zadanie 2</h1>
    <p>Student: Jakub_Stepuch</p>
    <p>Obraz kontenera został zbudowany automatycznie przez GitHub Actions.</p>
    <p>Finalny obraz publikowany jest do GitHub Container Registry.</p>
</body>
</html>
```

## Dockerfile

Obraz budowany jest na podstawie pliku `Dockerfile`.

Utworzenie pliku:

```bash
cat > Dockerfile <<'EOF'
FROM busybox:1.37

RUN adduser -D static

USER static
WORKDIR /home/static

COPY src .

CMD ["busybox", "httpd", "-f", "-v", "-p", "3000"]
EOF
```

Sprawdzenie zawartości:

```bash
cat Dockerfile
```

Wynik:

```dockerfile
FROM busybox:1.37

RUN adduser -D static

USER static
WORKDIR /home/static

COPY src .

CMD ["busybox", "httpd", "-f", "-v", "-p", "3000"]
```

Kontener uruchamia serwer HTTP BusyBox na porcie:

```text
3000
```

## Plik workflow GitHub Actions

Pipeline znajduje się w pliku:

```text
.github/workflows/zadanie2.yml
```

Utworzony workflow:

```yaml
name: Zadanie 2 - Build, scan and push image to GHCR

on:
  workflow_dispatch:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  packages: write

env:
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/tch-zadanie2
  CACHE_IMAGE: ${{ vars.DOCKERHUB_USERNAME }}/tch-zadanie2-cache:buildcache

jobs:
  build_scan_push:
    name: Build, scan and push Docker image
    runs-on: ubuntu-latest

    steps:
      - name: Check out source repository
        uses: actions/checkout@v6

      - name: Docker metadata definitions
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ env.IMAGE_NAME }}
          flavor: latest=false
          tags: |
            type=sha,priority=100,prefix=sha-,format=short
            type=semver,priority=200,pattern={{version}}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Login to DockerHub for BuildKit cache
        uses: docker/login-action@v4
        with:
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build local image for CVE scan
        uses: docker/build-push-action@v7
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64
          load: true
          tags: local/tch-zadanie2:cve-test
          cache-from: type=registry,ref=${{ env.CACHE_IMAGE }}
          cache-to: type=registry,ref=${{ env.CACHE_IMAGE }},mode=max

      - name: CVE scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: local/tch-zadanie2:cve-test
          vuln-type: os,library
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          exit-code: '1'
          format: table

      - name: Build and push multi-architecture image to GHCR
        uses: docker/build-push-action@v7
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          cache-from: type=registry,ref=${{ env.CACHE_IMAGE }}
          cache-to: type=registry,ref=${{ env.CACHE_IMAGE }},mode=max
          tags: ${{ steps.meta.outputs.tags }}
```

## Wyzwalanie pipeline

Workflow uruchamia się na dwa sposoby:

```yaml
on:
  workflow_dispatch:
  push:
    tags:
      - 'v*'
```

Oznacza to:

- `workflow_dispatch` - możliwość ręcznego uruchomienia z poziomu zakładki `Actions`,
- `push.tags: v*` - automatyczne uruchomienie po wypchnięciu taga zaczynającego się od `v`, np. `v1.0.0`.

Do uruchomienia pipeline użyto taga:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Uprawnienia do GHCR

W workflow dodano:

```yaml
permissions:
  contents: read
  packages: write
```

Znaczenie:

- `contents: read` - odczyt zawartości repozytorium,
- `packages: write` - możliwość publikowania obrazu w GitHub Container Registry.

Do logowania do GHCR wykorzystano wbudowany token GitHuba:

```yaml
- name: Login to GitHub Container Registry
  uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

## Publikacja finalnego obrazu

Finalny obraz publikowany jest do GitHub Container Registry:

```text
ghcr.io/jakubstepuch/tch-zadanie2
```

Nazwa obrazu w workflow:

```yaml
IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/tch-zadanie2
```

Po uruchomieniu pipeline obraz został opublikowany jako:

```text
ghcr.io/jakubstepuch/tch-zadanie2:1.0.0
```

## Obsługiwane architektury

Finalny obraz jest budowany dla dwóch architektur:

```text
linux/amd64
linux/arm64
```

Konfiguracja w workflow:

```yaml
platforms: linux/amd64,linux/arm64
```

Do budowania obrazu wieloarchitekturowego użyto:

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v4

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v4
```

## Cache BuildKit w DockerHub

Cache BuildKit jest przechowywany w publicznym repozytorium DockerHub:

```text
fives57/tch-zadanie2-cache:buildcache
```

Repozytorium cache na DockerHub:

```text
https://hub.docker.com/repository/docker/fives57/tch-zadanie2-cache
```

W workflow cache zdefiniowano jako:

```yaml
CACHE_IMAGE: ${{ vars.DOCKERHUB_USERNAME }}/tch-zadanie2-cache:buildcache
```

Pobieranie cache:

```yaml
cache-from: type=registry,ref=${{ env.CACHE_IMAGE }}
```

Zapisywanie cache:

```yaml
cache-to: type=registry,ref=${{ env.CACHE_IMAGE }},mode=max
```

Zastosowano eksporter `registry`, ponieważ dane cache miały być przechowywane w zewnętrznym rejestrze obrazów kontenerowych. Użycie `mode=max` pozwala zapisać szerszy zakres warstw cache, co zwiększa możliwość ich ponownego użycia przy następnych budowaniach.

W DockerHub potwierdzono utworzenie taga cache:

```text
buildcache
```

## Sekrety i zmienne GitHub Actions

Do obsługi cache w DockerHub ustawiono zmienną repozytorium GitHub:

```text
DOCKERHUB_USERNAME = fives57
```

Użyte polecenie:

```bash
gh variable set DOCKERHUB_USERNAME --body "fives57"
gh variable list
```

Wynik:

```text
✓ Created variable DOCKERHUB_USERNAME for jakubstepuch/tch-zadanie2
NAME                VALUE    UPDATED
DOCKERHUB_USERNAME  fives57  less than a minute ago
```

Ustawiono również sekret:

```text
DOCKERHUB_TOKEN
```

Użyte polecenie:

```bash
gh secret set DOCKERHUB_TOKEN
```

Wynik:

```text
✓ Set Actions secret DOCKERHUB_TOKEN for jakubstepuch/tch-zadanie2
```

Sprawdzenie sekretu:

```bash
gh secret list
```

Wynik:

```text
NAME             UPDATED
DOCKERHUB_TOKEN  less than a minute ago
```

Sekret `DOCKERHUB_TOKEN` zawiera token PAT wygenerowany na koncie DockerHub. Token nie jest zapisany w repozytorium.

## Test CVE

Test CVE wykonano narzędziem Trivy.

Najpierw pipeline buduje lokalny obraz testowy:

```yaml
- name: Build local image for CVE scan
  uses: docker/build-push-action@v7
  with:
    context: .
    file: ./Dockerfile
    platforms: linux/amd64
    load: true
    tags: local/tch-zadanie2:cve-test
    cache-from: type=registry,ref=${{ env.CACHE_IMAGE }}
    cache-to: type=registry,ref=${{ env.CACHE_IMAGE }},mode=max
```

Następnie wykonywany jest skan CVE:

```yaml
- name: CVE scan with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: local/tch-zadanie2:cve-test
    vuln-type: os,library
    severity: HIGH,CRITICAL
    ignore-unfixed: true
    exit-code: '1'
    format: table
```

Znaczenie najważniejszych parametrów:

- `severity: HIGH,CRITICAL` - sprawdzane są podatności wysokie i krytyczne,
- `ignore-unfixed: true` - pomijane są podatności bez dostępnej poprawki,
- `vuln-type: os,library` - sprawdzane są pakiety systemowe i biblioteki,
- `exit-code: '1'` - wykrycie podatności zatrzymuje workflow.

Krok publikujący obraz do GHCR znajduje się dopiero po kroku skanowania. Dzięki temu obraz jest wysyłany do GHCR tylko wtedy, gdy skan CVE zakończy się powodzeniem.

## Tagowanie obrazów

Do tagowania obrazów użyto `docker/metadata-action`.

Konfiguracja:

```yaml
tags: |
  type=sha,priority=100,prefix=sha-,format=short
  type=semver,priority=200,pattern={{version}}
```

Zastosowano dwa schematy tagowania.

### Tag SHA

Dla ręcznego uruchomienia workflow tworzony jest tag oparty o skrócony hash commita:

```text
sha-<hash>
```

Pozwala to powiązać obraz z konkretnym commitem.

### Tag semver

Dla uruchomienia przez tag Git:

```text
v1.0.0
```

tworzony jest tag obrazu:

```text
1.0.0
```

Schemat `semver` ma wyższy priorytet:

```text
priority=200
```

Schemat `sha` ma niższy priorytet:

```text
priority=100
```

Dzięki temu przy wydaniu wersji przez tag `v*` głównym tagiem obrazu jest numer wersji. Nie tworzono tagu `latest`, ponieważ ustawiono:

```yaml
flavor: latest=false
```

Taki schemat tagowania daje jednoznaczne powiązanie obrazu z wersją aplikacji lub z konkretnym commitem.

## Inicjalizacja repozytorium Git

Repozytorium lokalne utworzono poleceniami:

```bash
git init -b main
git config user.name "Jakub Stepuch"
git config user.email "jakub.stepuch@gmail.com"

git status
git add .
git commit -m "Initial solution for cloud technologies task 2"
```

Wynik commita:

```text
[main (zapis-korzeń) 2c53f65] Initial solution for cloud technologies task 2
 5 files changed, 130 insertions(+)
 create mode 100644 .github/workflows/zadanie2.yml
 create mode 100644 .gitignore
 create mode 100644 Dockerfile
 create mode 100644 README.md
 create mode 100644 src/index.html
```

## Utworzenie repozytorium GitHub

Repozytorium GitHub utworzono poleceniem:

```bash
gh repo create tch-zadanie2 --public --source=. --remote=origin --push
```

Wynik:

```text
✓ Created repository jakubstepuch/tch-zadanie2 on github.com
  https://github.com/jakubstepuch/tch-zadanie2
✓ Added remote https://github.com/jakubstepuch/tch-zadanie2.git
To https://github.com/jakubstepuch/tch-zadanie2.git
 * [new branch]      HEAD -> main
branch 'main' set up to track 'origin/main'.
✓ Pushed commits to https://github.com/jakubstepuch/tch-zadanie2.git
```

## Uruchomienie workflow

Pipeline uruchomiono przez wypchnięcie taga:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Wynik:

```text
To https://github.com/jakubstepuch/tch-zadanie2.git
 * [new tag]         v1.0.0 -> v1.0.0
```

Status workflow sprawdzono poleceniami:

```bash
gh run list
gh run watch
```

Wynik:

```text
✓ v1.0.0 Zadanie 2 - Build, scan and push image to GHCR · 26397140734
Triggered via push about 1 minute ago

JOBS
✓ Build, scan and push Docker image in 1m6s (ID 77700369123)
  ✓ Set up job
  ✓ Check out source repository
  ✓ Docker metadata definitions
  ✓ Set up QEMU
  ✓ Set up Docker Buildx
  ✓ Login to DockerHub for BuildKit cache
  ✓ Login to GitHub Container Registry
  ✓ Build local image for CVE scan
  ✓ CVE scan with Trivy
  ✓ Build and push multi-architecture image to GHCR
  ✓ Complete job

✓ Run Zadanie 2 - Build, scan and push image to GHCR (26397140734) completed with 'success'
```

Szczegóły uruchomienia:

```bash
gh run view 26397140734
```

Wynik:

```text
✓ v1.0.0 Zadanie 2 - Build, scan and push image to GHCR · 26397140734
Triggered via push about 6 minutes ago

JOBS
✓ Build, scan and push Docker image in 1m6s (ID 77700369123)

ARTIFACTS
jakubstepuch~tch-zadanie2~1TC5J4.dockerbuild
jakubstepuch~tch-zadanie2~PX4C48.dockerbuild

View this run on GitHub: https://github.com/jakubstepuch/tch-zadanie2/actions/runs/26397140734
```

## Test obrazu z GHCR

Po poprawnym wykonaniu workflow pobrano obraz z GHCR:

```bash
docker pull ghcr.io/jakubstepuch/tch-zadanie2:1.0.0
```

Wynik:

```text
1.0.0: Pulling from jakubstepuch/tch-zadanie2
3d83a576c216: Pull complete
436a1b1fd078: Pull complete
4f4fb700ef54: Pull complete
809b9b2dbe6d: Pull complete
5ed0e9b150f0: Download complete
Digest: sha256:4a571caca621c3e555cce44b88b4b5e0562c94f7bcd36e0c24f7b9e21d64106e
Status: Downloaded newer image for ghcr.io/jakubstepuch/tch-zadanie2:1.0.0
ghcr.io/jakubstepuch/tch-zadanie2:1.0.0
```

Uruchomiono kontener:

```bash
docker rm -f tch-zadanie2-test 2>/dev/null

docker run -d   --name tch-zadanie2-test   -p 3000:3000   ghcr.io/jakubstepuch/tch-zadanie2:1.0.0
```

Wynik:

```text
76ecef5b4b8c344cfea1ece55627002a1604c98cf7fe28a3c98d463c057fe316
```

Test działania aplikacji:

```bash
curl http://localhost:3000
```

Wynik:

```html
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>Technologie Chmurowe - Zadanie 2</title>
</head>
<body>
    <h1>Technologie Chmurowe - Zadanie 2</h1>
    <p>Student: Jakub_Stepuch</p>
    <p>Obraz kontenera został zbudowany automatycznie przez GitHub Actions.</p>
    <p>Finalny obraz publikowany jest do GitHub Container Registry.</p>
</body>
</html>
```

Dodatkowo aplikację sprawdzono z poziomu przeglądarki pod adresem:

```text
http://10.0.0.109:3000
```

Strona została wyświetlona poprawnie.

## Potwierdzenie publikacji

Potwierdzono utworzenie pakietu w GitHub Packages:

```text
tch-zadanie2
```

Pakiet widoczny jest na koncie:

```text
https://github.com/jakubstepuch?tab=packages
```

Potwierdzono również zapis cache w DockerHub:

```text
fives57/tch-zadanie2-cache
```

Repozytorium cache zawiera tag:

```text
buildcache
```

## Podsumowanie

W ramach zadania wykonano:

- przygotowanie aplikacji HTML,
- przygotowanie pliku `Dockerfile`,
- przygotowanie workflow GitHub Actions,
- konfigurację zmiennej `DOCKERHUB_USERNAME`,
- konfigurację sekretu `DOCKERHUB_TOKEN`,
- publikację kodu w repozytorium GitHub,
- uruchomienie workflow przez tag `v1.0.0`,
- budowanie obrazu dla `linux/amd64` oraz `linux/arm64`,
- użycie cache BuildKit w DockerHub z `mode=max`,
- skan CVE z użyciem Trivy,
- publikację finalnego obrazu do GHCR,
- pobranie obrazu z GHCR,
- uruchomienie kontenera i test działania aplikacji.

Link do repozytorium:

```text
https://github.com/jakubstepuch/tch-zadanie2
```

