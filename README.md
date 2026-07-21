# Documentation

[Home - Exchange Docs](./exchange-docs/home.md)

[Changelog](./exchange-docs/CHANGELOG.md)

## Running the tests

MUnit suites live in `src/test/munit`. Run them all with:

```
mvn clean verify
```

No real Anypoint org id is needed: Exchange publication only runs under the `release` profile, which `build.sh deploy` activates automatically.
