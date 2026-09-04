# SearchOps — uputstvo na srpskom

Paket sadrži kompletan produkcijski blueprint i **120 numerisanih Codex promptova** za izradu Rails SaaS MVP-a.

## Šta je uključeno

- kompletan PRD v1;
- modularna Rails arhitektura;
- ERD u Mermaid formatu i opis tabela;
- RBAC permission matrica;
- plan, feature, entitlement i quota matrica;
- početni katalog SEO, performance, AI-crawler, ASO i deep-link pravila;
- threat model za multi-tenancy, billing, OAuth i SSRF-bezbedan crawler;
- integracije, test strategija i produkcijski runbook;
- ADR odluke;
- execution tracker sa JSON stanjem, logom i Ruby CLI alatom;
- promptovi od praznog repozitorijuma do produkcionog MVP-a.

## Provera paketa

```bash
ruby tracking/scripts/validate_blueprint.rb
ruby tracking/scripts/test_prompt_tracker.rb
ruby tracking/scripts/prompt_tracker.rb validate
```

## Redosled rada

1. Raspakuj sadržaj u novi Git repozitorijum.
2. Otvori repozitorijum kao Codex projekat.
3. Pokreni prompt `000`.
4. Posle svakog prompta proveri testove i diff.
5. Sledeći prompt dobijaš komandom:

```bash
ruby tracking/scripts/prompt_tracker.rb next
```

Status celog projekta:

```bash
ruby tracking/scripts/prompt_tracker.rb status
```

Prompt se ne označava kao završen dok implementacija, testovi, dokumentacija i tracker nisu usklađeni.

## Važna odluka

RBAC, plan feature pristup i potrošni limiti su odvojeni sistemi:

```text
permission dozvoljava akciju članu
AND entitlement dozvoljava funkciju organizaciji
AND quota dozvoljava trenutnu potrošnju
```

Ne koristiti proveru poput `organization.plan == "growth"` u poslovnom kodu.


## Validirani obim

- 120 zasebnih promptova;
- 57 permission ključeva i 8 sistemskih uloga;
- 5 planova i 47 entitlement ključeva po planu;
- 96 početnih SEO/ASO/deep-link pravila;
- 10 ADR odluka i 4 JSON šeme.
