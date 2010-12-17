-define(MSG(From, Group, Msg), {pg_message, From, Group, Msg}).
-define(FieldId(Rec, Field), string:str(record_info(fields, Rec), [Field]) + 1).


-define(db_ref, {global, gtracker_db}).
-define(MAX_CALL_TIMEOUT, 30000).
