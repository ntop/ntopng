.. _ClickHouse:

Historical Flow Analysis JSON Example
-------------------------------------
.. code:: bash

    {
        "name" : "Applications",
        "data_source" : "flows",
        "chart" : [
        {
            "chart_id" : "top_l7_proto", // Each id MUST be different
            "chart_name" : "Top App Proto",
            "chart_css_styles" : { 
                "max-height" : "25rem",
                "min-height" : "25rem",
            },
            "chart_endpoint" : "/lua/rest/v2/get/db/charts/top_l7_proto.lua",
            "chart_events" : { 
                "dataPointSelection" : "db_analyze"
            },
            "chart_gui_filter" : "l7proto", 
            "chart_sql_query" : "SELECT L7_PROTO,SUM(TOTAL_BYTES) AS bytes FROM flows WHERE ($WHERE) GROUP BY L7_PROTO ORDER BY bytes DESC",
            "chart_type" : "donut_apex_chart",
            "chart_record_value" : "bytes",
            "chart_aggregate_low_data" : true,
            "chart_record_label" : "L7_PROTO",
            "chart_width" : 4, 
            "chart_y_formatter" : "format_bytes", 
        },{
            "chart_id" : "l7_proto_per_flow", // Each id MUST be different
            "chart_name" : "Num Flows per App",
            "chart_css_styles" : { 
                "max-height" : "35rem",
                "min-height" : "35rem",
            },
            "chart_endpoint" : "/lua/rest/v2/get/db/charts/l7_proto_per_flow.lua",
            "chart_events" : { 
                "dataPointSelection" : "db_analyze"
            },
            "chart_gui_filter" : "l7proto", 
            "chart_sql_query" : "SELECT L7_PROTO,COUNT(*) AS flows FROM flows WHERE ($WHERE) GROUP BY L7_PROTO ORDER BY flows DESC LIMIT 15",
            "chart_type" : "treemap_apex_chart",
            "chart_i18n_extra_x_label" : "flows",
            "chart_record_value" : "flows",
            "chart_record_label" : "L7_PROTO",
            "chart_width" : 6, 
            "chart_y_formatter" : "format_value", 
        },{
            "chart_id" : "highest_avg_flow_size_per_l7", // Each id MUST be different
            "chart_name" : "Avg Flow Size per App",
            "chart_css_styles" : { 
                "max-height" : "35rem",
                "min-height" : "35rem",
            },
            "chart_endpoint" : "/lua/rest/v2/get/db/charts/l7_proto_per_flow.lua",
            "chart_events" : { 
                "dataPointSelection" : "db_analyze"
            },
            "chart_gui_filter" : "l7proto", 
            "chart_sql_query" : "SELECT L7_PROTO,avg(TOTAL_BYTES) AS avg_bytes FROM flows WHERE ($WHERE) GROUP BY L7_PROTO ORDER BY avg_bytes DESC LIMIT 15",
            "chart_type" : "bar_apex_chart",
            "chart_i18n_extra_x_label" : "flow_size",
            "chart_record_value" : "avg_bytes",
            "chart_record_label" : "L7_PROTO",
            "chart_width" : 6, 
            "chart_y_formatter" : "format_bytes",
        }],
        "show_in_page" : "analysis",
    }
