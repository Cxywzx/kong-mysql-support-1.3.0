return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "oauth2_credentials" (
        "id"             UUID                         PRIMARY KEY,
        "created_at"     TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"           TEXT,
        "consumer_id"    UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "client_id"      TEXT                         UNIQUE,
        "client_secret"  TEXT,
        "redirect_uri"   TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_consumer_idx" ON "oauth2_credentials" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_secret_idx" ON "oauth2_credentials" ("client_secret");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_authorization_codes" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "api_id"                UUID                         REFERENCES "apis" ("id") ON DELETE CASCADE,
        "code"                  TEXT                         UNIQUE,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_userid_idx" ON "oauth2_authorization_codes" ("authenticated_userid");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_tokens" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "api_id"                UUID                         REFERENCES "apis" ("id") ON DELETE CASCADE,
        "access_token"          TEXT                         UNIQUE,
        "refresh_token"         TEXT                         UNIQUE,
        "token_type"            TEXT,
        "expires_in"            INTEGER,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_token_userid_idx" ON "oauth2_tokens" ("authenticated_userid");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS oauth2_credentials(
        id            uuid PRIMARY KEY,
        created_at    timestamp,
        consumer_id   uuid,
        client_id     text,
        client_secret text,
        name          text,
        redirect_uri  text
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(consumer_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_secret);



      CREATE TABLE IF NOT EXISTS oauth2_authorization_codes(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        api_id               uuid,
        credential_id        uuid,
        authenticated_userid text,
        code                 text,
        scope                text
      ) WITH default_time_to_live = 300;
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(code);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(api_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(authenticated_userid);



      CREATE TABLE IF NOT EXISTS oauth2_tokens(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        api_id               uuid,
        credential_id        uuid,
        access_token         text,
        authenticated_userid text,
        refresh_token        text,
        scope                text,
        token_type           text,
        expires_in           int
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(api_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(access_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(refresh_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(authenticated_userid);
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE `oauth2_credentials` (
      `id` varchar(50) PRIMARY KEY,
      `created_at` timestamp NOT NULL,
      `name` text ,
      `consumer_id` varchar(50),
      `client_id` text ,
      `client_secret` text ,
      `redirect_uris` text ,-- #Becareful, it is text array
      FOREIGN KEY (`consumer_id`) REFERENCES `consumers`(`id`) ON DELETE CASCADE
      ) ENGINE=INNODB DEFAULT CHARSET=utf8;

      -- ----------------------------
      -- Indexes structure for table oauth2_credentials
      -- ----------------------------
      CREATE INDEX oauth2_credentials_consumer_id_idx ON oauth2_credentials  (`consumer_id`);
      CREATE INDEX oauth2_credentials_secret_idx ON oauth2_credentials  (`client_secret`(50));

      -- ----------------------------
      -- Uniques structure for table oauth2_credentials
      -- ----------------------------
      ALTER TABLE oauth2_credentials ADD CONSTRAINT oauth2_credentials_client_id_key UNIQUE (`client_id`(50));

      -- ----------------------------
      -- Foreign Keys structure for table oauth2_credentials
      -- ----------------------------
      ALTER TABLE oauth2_credentials ADD CONSTRAINT oauth2_credentials_consumer_id_fkey FOREIGN KEY (`consumer_id`) REFERENCES consumers (`id`) ON DELETE CASCADE;


      CREATE TABLE `oauth2_authorization_codes` (
      `id` varchar(50) PRIMARY KEY,
      `created_at` timestamp NOT NULL,
      `credential_id` varchar(50),
      `service_id` varchar(50),
      `code` text ,
      `authenticated_userid` text ,
      `scope` text ,
      `ttl` timestamp,
      FOREIGN KEY (`credential_id`) REFERENCES `oauth2_credentials`(`id`) ON DELETE CASCADE,
      FOREIGN KEY (`service_id`) REFERENCES `services`(`id`) ON DELETE CASCADE
      ) ENGINE=INNODB DEFAULT CHARSET=utf8;

      -- ----------------------------
      -- Indexes structure for table oauth2_authorization_codes
      -- ----------------------------
      CREATE INDEX oauth2_authorization_codes_authenticated_userid_idx ON oauth2_authorization_codes  (`authenticated_userid`(50));
      CREATE INDEX oauth2_authorization_credential_id_idx ON oauth2_authorization_codes  (`credential_id`);
      CREATE INDEX oauth2_authorization_service_id_idx ON oauth2_authorization_codes  (`service_id`);

      -- ----------------------------
      -- Uniques structure for table oauth2_authorization_codes
      -- ----------------------------
      ALTER TABLE oauth2_authorization_codes ADD CONSTRAINT oauth2_authorization_codes_code_key UNIQUE (`code`(50));

      -- ----------------------------
      -- Foreign Keys structure for table oauth2_authorization_codes
      -- ----------------------------
      ALTER TABLE oauth2_authorization_codes ADD CONSTRAINT oauth2_authorization_codes_credential_id_fkey FOREIGN KEY (`credential_id`) REFERENCES oauth2_credentials (`id`) ON DELETE CASCADE;
      ALTER TABLE oauth2_authorization_codes ADD CONSTRAINT oauth2_authorization_codes_service_id_fkey FOREIGN KEY (`service_id`) REFERENCES services (`id`) ON DELETE CASCADE;


      CREATE TABLE `oauth2_tokens` (
      `id` varchar(50) PRIMARY KEY,
      `created_at` timestamp NOT NULL,
      `credential_id` varchar(50),
      `service_id` varchar(50),
      `access_token` text ,
      `refresh_token` text ,
      `token_type` text ,
      `expires_in` int4,
      `authenticated_userid` text ,
      `scope` text ,
      `ttl` timestamp,
      FOREIGN KEY (`credential_id`) REFERENCES `oauth2_credentials`(`id`) ON DELETE CASCADE,
      FOREIGN KEY (`service_id`) REFERENCES `services`(`id`) ON DELETE CASCADE
      ) ENGINE=INNODB DEFAULT CHARSET=utf8;

      -- ----------------------------
      -- Indexes structure for table oauth2_tokens
      -- ----------------------------
      CREATE INDEX oauth2_tokens_authenticated_userid_idx ON oauth2_tokens  (`authenticated_userid`(50));
      CREATE INDEX oauth2_tokens_credential_id_idx ON oauth2_tokens  (`credential_id`);
      CREATE INDEX oauth2_tokens_service_id_idx ON oauth2_tokens  (`service_id`);

      -- ----------------------------
      -- Uniques structure for table oauth2_tokens
      -- ----------------------------
      ALTER TABLE oauth2_tokens ADD CONSTRAINT oauth2_tokens_access_token_key UNIQUE (`access_token`(50));
      ALTER TABLE oauth2_tokens ADD CONSTRAINT oauth2_tokens_refresh_token_key UNIQUE (`refresh_token`(50));

      -- ----------------------------
      -- Foreign Keys structure for table oauth2_tokens
      -- ----------------------------
      ALTER TABLE oauth2_tokens ADD CONSTRAINT oauth2_tokens_credential_id_fkey FOREIGN KEY (`credential_id`) REFERENCES oauth2_credentials (`id`) ON DELETE CASCADE;
      ALTER TABLE oauth2_tokens ADD CONSTRAINT oauth2_tokens_service_id_fkey FOREIGN KEY (`service_id`) REFERENCES services (`id`) ON DELETE CASCADE;
    ]],
  },

}
