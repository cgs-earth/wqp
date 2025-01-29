FROM internetofwater/frost-server-http:develop-bw-2.6.0-SNAPSHOT
# FROM fraunhoferiosb/frost-server:2.1

ENV plugins_multiDatastream_enable=false
ENV http_cors_enable=true
ENV http_cors_allowed_origins=*
ENV persistence_db_driver=org.postgresql.Driver
ENV persistence_autoUpdateDatabase=true
ENV persistence_idGenerationMode=ServerAndClientGenerated
ENV plugins_coreModel_editableDsProperties=true
ENV plugins_coreModel_idType_thing=STRING
ENV plugins_coreModel_idType_observedProperty=STRING
ENV plugins_coreModel_idType_datastream=STRING
ENV maxTop=10000
ENV defaultTop=1000
ENV mqtt_Enabled=false
ENV bus_queueSize=1000
ENV bus_workerPoolSize=3
