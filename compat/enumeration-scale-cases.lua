local values={}; for i=1025,1,-1 do values[#values+1]=i end
return {
 {id='scale_map_sum',formula='SUM(MAP(vals,v,v+1))',context={vals=values},expected="number:526850"},
 {id='scale_filter_sum',formula='SUM(FILTER(vals,v,v>1020))',context={vals=values},expected="number:5115"},
 {id='scale_all',formula='ALL(vals,v,v>0)',context={vals=values},expected="boolean:true"},
 {id='scale_any_last',formula='ANY(vals,v,v=1)',context={vals=values},expected="boolean:true"},
 {id='scale_reduce',formula='REDUCE(vals,memo,v,memo+v,0)',context={vals=values},expected="number:525825"},
 {id='scale_map_count',formula='COUNT(MAP(vals,v,v+1))',context={vals=values},expected="number:1025"},
 {id='scale_case_body',formula='SUM(MAP(vals,v,CASE v WHEN 1025 THEN -0.0 ELSE v END))',context={vals=values},expected="number:524800"},
}
