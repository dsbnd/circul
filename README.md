# SOA, лабораторная работа №3

Проект развивает API лабораторной №2 до микросервисной архитектуры, не меняя
публичные REST-контракты.

## Архитектура

```text
Browser -> Flask client -> Zuul API Gateway
                           |-- /api/v1/** -> Ribbon -> Eureka -> Ticket Service
                           `-- /booking/** -> HAProxy -> Booking Service #1/#2

Config Server -> внешняя конфигурация Ticket Service
```

Компоненты:

- `config-server` — Spring Cloud Config Server;
- `eureka-server` — Service Discovery;
- `api-gateway` — Zuul Proxy и Ribbon;
- `ticket-service` — вызываемый сервис, зарегистрированный в Eureka;
- `booking-service` — вызывающий Spring Boot-сервис;
- `haproxy/haproxy.cfg` — round-robin балансировка двух Booking Service;
- `.run/cloud/booking.db` — общее SQLite-хранилище двух Booking Service;
- `client` — прежнее клиентское приложение, обращающееся только к Gateway.

Zuul и Ribbon оставлены на совместимой ветке Spring Boot 2.3 / Spring Cloud
Hoxton, потому что именно эти технологии прямо требуются формулировкой задания.
Остальные Spring-компоненты используют ветку 3.4.

## Сборка и запуск на Helios

Требуются Java 17, Maven, Python 3 и HAProxy.

```bash
./scripts/build-cloud.sh
./scripts/start-cloud-helios.sh
```

Порты по умолчанию:

- Config Server — `18330`;
- Eureka — `18430`;
- Ticket Service — `18030`;
- Zuul Gateway — `18530`;
- HAProxy — `18130`;
- Booking Service — `18131` и `18132`;
- клиент — `18230` (HTTPS).

Остановка:

```bash
./scripts/stop-cloud-helios.sh
```

Все порты можно переопределить одноимёнными переменными окружения из скрипта.
HAProxy добавляет ответный заголовок `X-Booking-Instance`, по которому видно,
какой экземпляр обработал запрос.

## Локальные значения по умолчанию

При ручном запуске используются стандартные порты: Config `8888`, Eureka
`8761`, Ticket `8081`, Gateway `8080`, HAProxy `8085`, Booking `8082`/`8083`.
Клиент по умолчанию направляет и Ticket-, и Booking-запросы через Gateway.
