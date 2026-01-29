
# Enable Logging

To enable logging:

Open the log4j2.xml file inside the folder `src/main/resources`.
ℹ️ You can also configure directly in the CloudHub application settings if you need to enable wire logging in a deployed application.

If the following line is already in the log4j2.xml file, uncomment it to enable it; otherwise, add it:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
    ...
    <Loggers>
        ...
        <AsyncLogger name="org.mulesoft.modules.errorhandler" level="DEBUG"/>
        ...
    </Loggers>
</Configuration>
```

Save your changes.

Restart your Mule application to apply the changes.
