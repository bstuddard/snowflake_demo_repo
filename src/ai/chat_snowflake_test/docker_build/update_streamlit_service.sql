ALTER SERVICE chat_snowflake_demo_service SUSPEND;
DESCRIBE SERVICE chat_snowflake_demo_service;

--Once stopped, repush image using build_and_push.bat

ALTER SERVICE chat_snowflake_demo_service
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: streamlit
        image: /learning_db/ai/container_repository/chat_snowflake_demo:latest
        env:
          TEST_VAR: test
        readinessProbe:
          port: 8501
          path: /_stcore/health
      endpoints:
      - name: streamlitendpoint
        port: 8501
        public: true
      $$;

ALTER SERVICE chat_snowflake_demo_service RESUME;
DESCRIBE SERVICE chat_snowflake_demo_service;

SHOW ENDPOINTS IN SERVICE chat_snowflake_demo_service;