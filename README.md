# podman-dev

<!-- Command used, with the newly updated entrypoint.sh and compose.yaml files (both of which were last updated approximately July 29, 2025): -->

```sh
podman-compose --env-file .env up
```

# NOTES:

## General

- I'm not using podman secrets, nor am I exporting anything prior to issuing this command. 
- I've tested with the official oracle db/latest (as of ~July 2025); not Gerald's. So, I'm not sure what his entrypoint.sh script looks like. the `test_database` function could probably be added to his file though. Untested, not sure at all though!!

## Weblogic

- Having tested the Remote Console, it doesn't the user with a lot of actionable insight. In a final (i.e., "I'm going to give up after this, after 3 days of diagnosing...") attempt I explicilty set the `PRODUCTION_MODE=dev` and in the Provider Information for the Remote Console (for establishing a connection to the Admin Server), I used the following values[^1]: 

[^1]: I discovered [this SO thread](https://stackoverflow.com/questions/63684437/unable-to-access-weblogic-console-in-container), where a similar symptom was described.

    | | |
    | -- | -- |
    | Connection Provider Name | test | 
    | Username | [Username] |
    | Password | [Password] | 
    | URL | `https://localhost:9002` | 
    |Make Insecure Connection | ✅ Yes | 

    > :note: Username and Password are the ones you will have provided in the `domain.properties` file. See the `compose.yaml` file for an example--it is the `./` in the volumes section for the WLS service. 
    
    The `./` is a shortcut for pointing to the `podman-dev` directory. That way, if you decide to rename that directory, it will simply refer to `./` instead of the name (which may have changed, which will result in a failed deployment).

### Updating the ORDS configuration

The `ords.war` contains the following:

```shell
.
├── META-INF
│   ├── MANIFEST.MF
│   ├── ORACLE_C.RSA
│   └── ORACLE_C.SF
├── oracle
│   └── dbtools
│       └── launcher
│           ├── CommandLineParser.class
│           ├── executable
│           │   └── jar
│           │       ├── Builder.class
│           │       ├── ExecutableJar.class
│           │       ├── ExecutableJar$1.class
│           │       ├── ExecutableJarEntrypoint.class
│           │       ├── ExtensionLibraryClassLoader.class
│           │       ├── HandlerFactory.class
│           │       ├── HasSize.class
│           │       ├── JarManifest.class
│           │       ├── JarManifest$Builder.class
│           │       ├── JarManifest$Section.class
│           │       ├── JarManifest$Section$Builder.class
│           │       ├── JarProcessor.class
│           │       ├── MutatedZip.class
│           │       ├── NestedJarClassLoader.class
│           │       ├── NestedJarClassLoader$AlsoClose.class
│           │       ├── NestedJarClassLoader$Archive.class
│           │       ├── NestedJarClassLoader$ArchiveConnection.class
│           │       ├── NestedResourceHandler.class
│           │       ├── OracleHomeClassLoader.class
│           │       ├── Resource.class
│           │       ├── Resource$ContentStream.class
│           │       ├── ResourceBuilder.class
│           │       ├── Resources.class
│           │       └── Resources$Builder.class
│           ├── Launcher.class
│           ├── Launcher$Builder.class
│           ├── Launcher$MainClassNotSpecifiedException.class
│           └── zip
│               ├── Bytes.class
│               ├── Bytes$BytesBuffer.class
│               ├── Bytes$BytesSubRange.class
│               ├── Bytes$FileRanges.class
│               ├── Bytes$HexDump.class
│               ├── Bytes$MappedBytes.class
│               ├── Bytes$ScopedSegmentFactory.class
│               ├── Bytes$ScopedSegmentFactory$ScopedSegment.class
│               ├── Bytes$SharedBytes.class
│               ├── Bytes$SubRange.class
│               ├── BytesRange.class
│               ├── CompressedStream.class
│               ├── EZipBuilder.class
│               ├── EZipBuilder$StorageMethod.class
│               ├── ZipConstants.class
│               ├── ZipIndex.class
│               ├── ZipItem.class
│               ├── ZipLocation.class
│               ├── ZipLocations.class
│               ├── ZipOutputStream.class
│               ├── ZipOutputStream$XEntry.class
│               ├── Zips.class
│               └── ZipUtils.class
└── WEB-INF
    ├── beans.xml
    ├── classes
    ├── lib
    │   ├── analysisCore-20.3.1.187.jar
    │   ├── analysisJdbc-20.3.1.187.jar
    │   ├── angus-activation-2.0.2.jar
    │   ├── antlr4-runtime-4.13.2.jar
    │   ├── aopalliance-repackaged-2.6.1.jar
    │   ├── autoupgrade-plugin-25.1.0.099.1519.jar
    │   ├── bson-5.3.1.jar
    │   ├── caffeine-3.2.0.jar
    │   ├── commons-codec-1.11.jar
    │   ├── commons-compress-1.27.1.jar
    │   ├── commons-fileupload-1.5.jar
    │   ├── commons-io-2.19.0.jar
    │   ├── commons-logging-1.2.jar
    │   ├── dbtools-arbori-25.2.0.157.0951.jar
    │   ├── dbtools-common-25.2.0.157.0951.jar
    │   ├── dbtools-core-25.2.0.157.0951.jar
    │   ├── dbtools-modeler-common-25.2.0.157.0951.jar
    │   ├── dbtools-oci-25.2.0.157.0951.jar
    │   ├── dbtools-ucp-25.2.0.157.0951.jar
    │   ├── georasterapi-repackaged-25.2.jar
    │   ├── guava-33.4.8-jre.jar
    │   ├── hk2-api-2.6.1.jar
    │   ├── hk2-locator-2.6.1.jar
    │   ├── hk2-utils-2.6.1.jar
    │   ├── httpclient-4.5.13.jar
    │   ├── httpcore-4.4.13.jar
    │   ├── istack-commons-runtime-4.1.2.jar
    │   ├── jackson-datatype-jsr310-2.17.2.jar
    │   ├── jackson-module-jaxb-annotations-2.12.2.jar
    │   ├── jackson-repackaged-2.18.3.jar
    │   ├── jakarta.activation-api-2.1.3.jar
    │   ├── jakarta.annotation-api-2.1.1.jar
    │   ├── jakarta.inject-2.6.1.jar
    │   ├── jakarta.inject-api-2.0.1.jar
    │   ├── jakarta.json-api-2.1.1.jar
    │   ├── jakarta.servlet-api-4.0.4.jar
    │   ├── jakarta.ws.rs-api-2.1.6.jar
    │   ├── jakarta.xml.bind-api-4.0.2.jar
    │   ├── jansi-2.4.1.jar
    │   ├── javassist-3.25.0-GA.jar
    │   ├── javax.activation-api-1.2.0.jar
    │   ├── javax.annotation-api-1.3.2.jar
    │   ├── jaxb-core-4.0.5.jar
    │   ├── jaxb-runtime-4.0.5.jar
    │   ├── jersey-apache-connector-2.35.jar
    │   ├── jersey-client-2.35.jar
    │   ├── jersey-common-2.35.jar
    │   ├── jersey-entity-filtering-2.35.jar
    │   ├── jersey-hk2-2.35.jar
    │   ├── jersey-media-json-jackson-2.35.jar
    │   ├── jetty-alpn-client-12.0.18.jar
    │   ├── jetty-alpn-server-12.0.18.jar
    │   ├── jetty-client-12.0.18.jar
    │   ├── jetty-ee8-nested-12.0.18.jar
    │   ├── jetty-ee8-security-12.0.18.jar
    │   ├── jetty-ee8-servlet-12.0.18.jar
    │   ├── jetty-http-12.0.18.jar
    │   ├── jetty-http2-client-12.0.18.jar
    │   ├── jetty-http2-common-12.0.18.jar
    │   ├── jetty-http2-hpack-12.0.18.jar
    │   ├── jetty-http2-server-12.0.18.jar
    │   ├── jetty-io-12.0.18.jar
    │   ├── jetty-rewrite-12.0.18.jar
    │   ├── jetty-schemas-4.0.3.jar
    │   ├── jetty-security-12.0.18.jar
    │   ├── jetty-server-12.0.18.jar
    │   ├── jetty-servlet-api-4.0.6.jar
    │   ├── jetty-session-12.0.18.jar
    │   ├── jetty-util-12.0.18.jar
    │   ├── jetty-xml-12.0.18.jar
    │   ├── mockito-inline-4.9.0.jar
    │   ├── oci-java-sdk-bastion-3.57.1.jar
    │   ├── oci-java-sdk-circuitbreaker-3.57.1.jar
    │   ├── oci-java-sdk-common-3.57.1.jar
    │   ├── oci-java-sdk-common-httpclient-3.57.1.jar
    │   ├── oci-java-sdk-common-httpclient-jersey-3.57.1.jar
    │   ├── oci-java-sdk-database-3.57.1.jar
    │   ├── oci-java-sdk-databasetools-3.57.1.jar
    │   ├── oci-java-sdk-identity-3.57.1.jar
    │   ├── oci-java-sdk-monitoring-3.57.1.jar
    │   ├── oci-java-sdk-objectstorage-3.57.1.jar
    │   ├── oci-java-sdk-objectstorage-extensions-3.57.1.jar
    │   ├── oci-java-sdk-objectstorage-generated-3.57.1.jar
    │   ├── oci-java-sdk-secrets-3.57.1.jar
    │   ├── oci-java-sdk-workrequests-3.57.1.jar
    │   ├── ojdbc11-23.7.0.25.01.jar
    │   ├── ojmisc-11.2.0.4.0.jar
    │   ├── ons-23.7.0.25.01.jar
    │   ├── opentelemetry-api-1.41.0.jar
    │   ├── opentelemetry-context-1.41.0.jar
    │   ├── oraclepki-23.7.0.25.01.jar
    │   ├── orai18n-23.7.0.25.01.jar
    │   ├── orai18n-mapping-23.3.0.0.0.jar
    │   ├── orai18n-utility-23.3.0.0.0.jar
    │   ├── orajsoda-1.1.30.jar
    │   ├── oraml-core-250609.jar
    │   ├── oraml-jetty-250609.jar
    │   ├── orarestsoda-1.1.30.jar
    │   ├── ords-adp-analytics-client-25.2.0.165.1520.jar
    │   ├── ords-adp-analytics-server-25.2.0.165.1520.jar
    │   ├── ords-adp-avd-client-25.2.0.165.1520.jar
    │   ├── ords-adp-avd-server-25.2.0.165.1520.jar
    │   ├── ords-adp-di-client-25.2.0.165.1520.jar
    │   ├── ords-adp-di-server-25.2.0.165.1520.jar
    │   ├── ords-adp-ins-client-25.2.0.165.1520.jar
    │   ├── ords-adp-ins-server-25.2.0.165.1520.jar
    │   ├── ords-adp-lineage-client-25.2.0.165.1520.jar
    │   ├── ords-adp-lineage-server-25.2.0.165.1520.jar
    │   ├── ords-adp-odimp-client-25.2.0.165.1520.jar
    │   ├── ords-adp-odimp-server-25.2.0.165.1520.jar
    │   ├── ords-apex-support-25.2.0.165.1520.jar
    │   ├── ords-auth-25.2.0.165.1520.jar
    │   ├── ords-cache-25.2.0.165.1520.jar
    │   ├── ords-cmdline-25.2.0.165.1520.jar
    │   ├── ords-common-25.2.0.165.1520.jar
    │   ├── ords-common-ui-25.2.0.165.1520.jar
    │   ├── ords-conf-25.2.0.165.1520.jar
    │   ├── ords-db-api-25.2.0.165.1520.jar
    │   ├── ords-db-common-25.2.0.165.1520.jar
    │   ├── ords-embed-api-25.2.0.165.1520.jar
    │   ├── ords-entry-point-25.2.0.165.1520.jar
    │   ├── ords-filtering-25.2.0.165.1520.jar
    │   ├── ords-graphql-25.2.0.165.1520.jar
    │   ├── ords-http-25.2.0.165.1520.jar
    │   ├── ords-icap-25.2.0.165.1520.jar
    │   ├── ords-injector-25.2.0.165.1520.jar
    │   ├── ords-installer-25.2.0.165.1520.jar
    │   ├── ords-instance-api-25.2.0.165.1520.jar
    │   ├── ords-jdbc-pool-25.2.0.165.1520.jar
    │   ├── ords-jet-resources-25.2.0.165.1520.jar
    │   ├── ords-json-25.2.0.165.1520.jar
    │   ├── ords-landing-page-25.2.0.165.1520.jar
    │   ├── ords-metrics-25.2.0.165.1520.jar
    │   ├── ords-oauth-25.2.0.165.1520.jar
    │   ├── ords-plsql-gateway-25.2.0.165.1520.jar
    │   ├── ords-plugin-api-25.2.0.165.1520.jar
    │   ├── ords-plugin-apt-25.2.0.165.1520.jar
    │   ├── ords-rest-enabled-sql-25.2.0.165.1520.jar
    │   ├── ords-rest-services-25.2.0.165.1520.jar
    │   ├── ords-sdw-client-25.2.0.165.1520.jar
    │   ├── ords-sdw-server-25.2.0.165.1520.jar
    │   ├── ords-service-console-25.2.0.165.1520.jar
    │   ├── ords-sign-in-25.2.0.165.1520.jar
    │   ├── ords-soda-25.2.0.165.1520.jar
    │   ├── ords-standalone-25.2.0.165.1520.jar
    │   ├── ords-static-25.2.0.165.1520.jar
    │   ├── ords-static-shared-libs-25.2.0.165.1520.jar
    │   ├── ords-url-mapping-25.2.0.165.1520.jar
    │   ├── ords-web-client-25.2.0.165.1520.jar
    │   ├── osgi-resource-locator-1.0.3.jar
    │   ├── parsson-1.1.7.jar
    │   ├── resilience4j-circuitbreaker-1.7.1.jar
    │   ├── resilience4j-core-1.7.1.jar
    │   ├── sdoapi-25.2.jar
    │   ├── sdodep3prt-25.2.jar
    │   ├── sdordf-25.1.jar
    │   ├── sdordf-client-25.1.jar
    │   ├── sdordf-ords-25.1.jar
    │   ├── sdoutl-25.2.jar
    │   ├── slf4j-api-2.0.13.jar
    │   ├── sshd-osgi-2.13.2.jar
    │   ├── ucp11-23.7.0.25.01_37536533.jar
    │   ├── vavr-0.10.2.jar
    │   ├── vavr-match-0.10.2.jar
    │   ├── xdb-23.7.0.25.01.jar
    │   └── xmlparserv2_sans_jaxp_services-23.7.0.25.01.jar
    ├── web.xml
    └── weblogic.xml
```

> [!NOTE] 
> A `.war` file is bascially just a `.zip` file, so I'm not disclosing anything new or novel here. Anybody with the abiltity to change the file extension from `.war` to .`zip` can do this, and uncompress the file. 

"WebLogic Server supports deployments that are packaged either as archive files using the jar utility or Ant's jar tool, or as exploded archive directories."[^3] In the above file "tree" you'll see the exploded archive directories and its files.

[^3]: [Packaging Files for Deployment](https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/14.1.2/depgd/deployunits.html#GUID-C6C3090D-1010-4224-AB32-2949182AF948) as of WebLogic 14.1.2.

For the purposes of WebLogic, all we care about are the `beans.xml`, `web.xml`, and `weblogic.xml` files. Even still, all you are concerned with is the `web.xml` file. Otherwise known as a "Deployment Descriptor."[^2] Your ORDS installation will also have a `weblogic.xml` file-- another kind of Deployment Descriptor--but you do not need to modify this file. 

[^2]: [Details](https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/14.1.2/depgd/understanding.html#GUID-904A48A6-D89A-446D-A8E9-EDE4B44140DB) on the files contained in a `.war` file.

An unmodified version of ORDS will contain a `web.xml` file such as this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app
    metadata-complete="true"
    version="3.1" 
    id="ORDS"
    xmlns="http://xmlns.jcp.org/xml/ns/javaee" 
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd">
	<display-name>Oracle REST Data Services</display-name>

	<context-param>
		<param-name>version</param-name>
		<param-value>25.2.0.r1651520</param-value>
	</context-param>
	
	<listener>
		<listener-class>oracle.dbtools.entrypoint.WebApplicationEntryPoint</listener-class>
	</listener>

	<servlet>
		<description>
		</description>
		<display-name>HttpEndPoint</display-name>
		<servlet-name>HttpEndPoint</servlet-name>
		<servlet-class>oracle.dbtools.entrypoint.WebApplicationRequestEntryPoint</servlet-class>
	</servlet>

	<servlet-mapping>
		<servlet-name>HttpEndPoint</servlet-name>
		<url-pattern>/*</url-pattern>
	</servlet-mapping>

	<servlet>
		<description>
		</description>
		<display-name>Forbidden</display-name>
		<servlet-name>Forbidden</servlet-name>
		<servlet-class>oracle.dbtools.entrypoint.Forbidden</servlet-class>
	</servlet>

	<servlet-mapping>
		<servlet-name>Forbidden</servlet-name>
		<url-pattern>/oracle/dbtools/jarcl</url-pattern>
	</servlet-mapping>

	<welcome-file-list>
		<welcome-file>index.html</welcome-file>
		<welcome-file>index.htm</welcome-file>
		<welcome-file>index.jsp</welcome-file>
		<welcome-file>default.html</welcome-file>
		<welcome-file>default.htm</welcome-file>
		<welcome-file>default.jsp</welcome-file>
	</welcome-file-list>

  <!-- Disable auto-discovery of servlet 3+ web fragments -->
  <absolute-ordering /> 
</web-app>
```

You must define the location of the ORDS configuration directory by either:
1. manually adding it as `<context-param>` to this `web.xml` file and re-archiving the exploded archive into a new `ords.war` file (HIGHLY DISCOURAGED)
2. using the `ords war` command 
2. Set the `config.url` system property (i.e., the system where Weblogic is deployed, and prior to starting the WebLogic Server) with this command: `export JAVA_OPTIONS="-Dconfig.url=/path/to/ords_config"` 


The "ORDS Web Application" doesn't require/use/rely on

1. Copy the ords product folder to your WebLogic server
2. Create an empty ORDS configuration folder (e.g. `ords_config`)[^4]
3. Navigate to your ORDS product folder (unzip if not zipped), and navigate to the `/bin` folder

[^4]: You can name this anything, but naming it something that is related to ORDS' configuration makes sense. 


4. You'll need to temporarily set your $PATH to the ORDS `/bin`, like this:

    ```shell
    PATH=/path to your ords product folder/bin:$PATH
    ```

    ```shell
    export PATH
    ```

5. Then, `cd` to your `ords_config` folder and execute the following command: 

    ```shell
    ords war [/path/to/your/existing/ords.war]
    ```

> [!NOTE] 
> You can optionally create a new name for the recreated `ords.war` file (so as not to overwrite the original `ords.war` file) like this:
> 
> ```shell
> ords war my_new_file_name.war [/path/to/your/existing/ords.war]
> ```

6. Your new `ords.war` file will be located in your current directory. You can inspect it's `web.xml` file by issuing the following command: 

    ```shell
    jar -xf my_new_war_for_wls.war
    ```

7. Issue the `ls` command and you should see two objects: 
   - the new `.war` file, and 
   - a `WEB-INF` directory
   
   `cd` into the `WEB-INF` directory. A `web.xml` file will be visible. You can `cat` the file to review its contents. 

8. After issuing the `cat web.xml` command, you'll see something resembling the following sample `web.xml`:

    ```xml=
    <?xml version="1.0" encoding="UTF-8" standalone="no"?><web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="ORDS" metadata-complete="true" version="3.1" xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd">
        <display-name>Oracle REST Data Services</display-name>

        <context-param>
            <param-name>config.url</param-name>
            <param-value>/Users/choina/temp_config</param-value>
        </context-param><context-param>
            <param-name>version</param-name>
            <param-value>25.2.0.r1651520</param-value>
        </context-param>
        
        <listener>
            <listener-class>oracle.dbtools.entrypoint.WebApplicationEntryPoint</listener-class>
        </listener>

        <servlet>
            <description>
            </description>
            <display-name>HttpEndPoint</display-name>
            <servlet-name>HttpEndPoint</servlet-name>
            <servlet-class>oracle.dbtools.entrypoint.WebApplicationRequestEntryPoint</servlet-class>
        </servlet>

        <servlet-mapping>
            <servlet-name>HttpEndPoint</servlet-name>
            <url-pattern>/*</url-pattern>
        </servlet-mapping>

        <servlet>
            <description>
            </description>
            <display-name>Forbidden</display-name>
            <servlet-name>Forbidden</servlet-name>
            <servlet-class>oracle.dbtools.entrypoint.Forbidden</servlet-class>
        </servlet>

        <servlet-mapping>
            <servlet-name>Forbidden</servlet-name>
            <url-pattern>/oracle/dbtools/jarcl</url-pattern>
        </servlet-mapping>

        <welcome-file-list>
            <welcome-file>index.html</welcome-file>
            <welcome-file>index.htm</welcome-file>
            <welcome-file>index.jsp</welcome-file>
            <welcome-file>default.html</welcome-file>
            <welcome-file>default.htm</welcome-file>
            <welcome-file>default.jsp</welcome-file>
        </welcome-file-list>

    <!-- Disable auto-discovery of servlet 3+ web fragments -->
    <absolute-ordering/> 
    </web-app>
    ```








