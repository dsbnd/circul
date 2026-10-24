# Circus SOA

Проект для лабораторных работ по сервис-ориентированной архитектуре.

## Архитектура Spring Cloud

Вызываемый `ticket-service` сохраняет контракт `/api/v1/**` и теперь:

- получает настройки из Spring Cloud Config Server;
- регистрируется в Eureka как `ticket-service`;
- доступен клиентам через Zuul API Gateway;
- выбирается Ribbon на основании данных Eureka.

Инфраструктурные модули:

- `config-server` — централизованная конфигурация, локальный порт `8888`;
- `eureka-server` — Service Discovery, локальный порт `8761`;
- `api-gateway` — единая точка входа, локальный порт `8080`;
- `config-repo` — файловый репозиторий Config Server.

Zuul и Ribbon удалены из современных версий Spring Cloud. Поэтому Gateway
использует Spring Boot 2.3 и Spring Cloud Hoxton, а бизнес-сервис, Config Server
и Eureka используют Spring Boot 3.4 и Spring Cloud 2024. Они взаимодействуют
через HTTP API Eureka.

## Сборка

```bash
./scripts/build-cloud.sh
```

## Запуск на Helios

Spring Cloud-компоненты запускаются на Helios без Docker:

```bash
./scripts/start-cloud-helios.sh
```

Внутренние порты по умолчанию:

| Компонент | Порт |
| --- | ---: |
| Ticket Service | 18030 |
| Config Server | 18330 |
| Eureka Server | 18430 |
| Zuul API Gateway | 18530 |

Все компоненты слушают только `127.0.0.1`. Браузерный клиент должен использовать
Gateway для обоих API:

```bash
TICKET_SERVICE_URL=http://127.0.0.1:18530/api/v1
BOOKING_SERVICE_URL=http://127.0.0.1:18530/booking
```

Маршрут Booking уже зарезервирован в Zuul и направлен на
`BOOKING_LOAD_BALANCER_URL` (по умолчанию на Helios это
`http://127.0.0.1:18130`). Во второй части работы нужно добавить два экземпляра
Booking Service и HAProxy по этому адресу.

Остановка нашей части:

```bash
./scripts/stop-cloud-helios.sh
```

Порты переопределяются переменными `CONFIG_PORT`, `EUREKA_PORT`, `TICKET_PORT`,
`GATEWAY_PORT` и `BOOKING_LOAD_BALANCER_PORT`. Переменная
`TICKET_SERVICE_HOST` задаёт адрес, публикуемый в Eureka; по умолчанию это
`127.0.0.1`, поскольку все компоненты работают на одном сервере Helios.

## Передача второй части работы

Коллеге остаётся:

1. перенести `booking-service` с WildFly на Spring Boot без изменения
   `/booking/**`;
2. запустить экземпляры, например, на `18131` и `18132`;
3. настроить HAProxy на `127.0.0.1:18130`;
4. направить внутренний вызов Ticket Service на
   `http://127.0.0.1:18530/api/v1`;
5. запускать Flask-клиент с обоими URL через Gateway (`18530`);
6. объединить cloud-, booking-, HAProxy- и client-команды в итоговые скрипты
   запуска и остановки;
7. проверить внешний HTTPS-адрес клиента на Helios. Служебные компоненты
   Config, Eureka и Ticket наружу публиковать не нужно.
