t:([] sym:`a`b`a`c; px:1 2 3 4f);
r:select total:sum px by sym from t;
if[not (4 2 4f)~exec total from r; -2 "select by: ",-3!r; exit 1];
if[not "abc"~raze string `a`b`c; -2 "string"; exit 1];
-1 "smoke ok";
exit 0
