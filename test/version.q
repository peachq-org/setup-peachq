v:.z.v`version;
w:getenv`WANT;
if[not (0<count v) and v like w,"*"; -2 "peachq reports ",v,", wanted ",w; exit 1];
if[not v~.pq.version; -2 ".z.v and .pq.version disagree"; exit 1];
-1 "peachq ",v;
exit 0
