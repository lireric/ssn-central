CREATE DATABASE ssn
  WITH OWNER = ssn
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'C'
       LC_CTYPE = 'C.UTF-8'
       CONNECTION LIMIT = -1;


-- Table: public.ssn_teledata

-- DROP TABLE public.ssn_teledata;

CREATE TABLE public.ssn_teledata
(
  td_id bigint NOT NULL DEFAULT nextval('ssn_teledata_id_seq'::regclass), -- Unique ID of record
  td_account smallint, -- Account
  td_object smallint, -- Object
  td_device smallint NOT NULL, -- Device
  td_channel smallint NOT NULL DEFAULT 0, -- Channel of device (default=0)
  td_dev_ts integer, -- Timestamp from device (unix format)
  td_store_ts integer NOT NULL, -- Timestamp of storing in DB (unix format)
  td_dev_value integer NOT NULL, -- Value of device
  td_action smallint NOT NULL DEFAULT 0, -- Action number if value of device is changed by action or 0 if value changed by external factors.
  CONSTRAINT ssn_teledata_pkey PRIMARY KEY (td_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.ssn_teledata
  OWNER TO ssn;
COMMENT ON TABLE public.ssn_teledata
  IS 'Telemetry data';
COMMENT ON COLUMN public.ssn_teledata.td_id IS 'Unique ID of record';
COMMENT ON COLUMN public.ssn_teledata.td_account IS 'Account';
COMMENT ON COLUMN public.ssn_teledata.td_object IS 'Object';
COMMENT ON COLUMN public.ssn_teledata.td_device IS 'Device';
COMMENT ON COLUMN public.ssn_teledata.td_channel IS 'Channel of device (default=0)';
COMMENT ON COLUMN public.ssn_teledata.td_dev_ts IS 'Timestamp from device (unix format)';
COMMENT ON COLUMN public.ssn_teledata.td_store_ts IS 'Timestamp of storing in DB (unix format)';
COMMENT ON COLUMN public.ssn_teledata.td_dev_value IS 'Value of device';
COMMENT ON COLUMN public.ssn_teledata.td_action IS 'Action number if value of device is changed by action or 0 if value changed by external factors.';


-- Index: public.by_device_and_channel

-- DROP INDEX public.by_device_and_channel;

CREATE INDEX by_device_and_channel
  ON public.ssn_teledata
  USING btree
  (td_device, td_channel);

-- Index: public.by_store_ts

-- DROP INDEX public.by_store_ts;

CREATE INDEX by_store_ts
  ON public.ssn_teledata
  USING btree
  (td_store_ts DESC);

-- Index: public.ssn_teledata_td_account_td_object_idx

-- DROP INDEX public.ssn_teledata_td_account_td_object_idx;

CREATE INDEX ssn_teledata_td_account_td_object_idx
  ON public.ssn_teledata
  USING btree
  (td_account, td_object);

