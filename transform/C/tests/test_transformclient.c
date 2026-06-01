/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/testutil.h"
#include "../include/transformclient.h"
#include <stdlib.h>
#include <string.h>

TEST(test_json_parse_success)
{
    char *json = transform_json_parse("{\"a\":1}");
    ASSERT("parse 200", json_status(json) == 200);
    free(json);
}

TEST(test_json_parse_error)
{
    char *json = transform_json_parse("{bad");
    ASSERT("parse 400", json_status(json) == 400);
    free(json);
}

TEST(test_json_stringify)
{
    char *json = transform_json_stringify("{\"x\":\"y\"}");
    ASSERT("stringify 200", json_status(json) == 200);
    free(json);
}

TEST(test_csv_roundtrip)
{
    char *rows = transform_csv_to_rows("id,name\n1,Ada\n", ",");
    char *csv;

    ASSERT("csv 200", json_status(rows) == 200);
    csv = transform_rows_to_csv(
        "[{\"id\":\"1\",\"name\":\"Ada\"}]", ",");
    ASSERT("rows to csv 200", json_status(csv) == 200);
    free(rows);
    free(csv);
}

TEST(test_csv_empty_rows_error)
{
    char *json = transform_rows_to_csv("[]", ",");
    ASSERT("empty 400", json_status(json) == 400);
    free(json);
}

TEST(test_xml_roundtrip)
{
    char *parsed = transform_xml_to_dict("<root><item>ok</item></root>");
    char *xml;

    ASSERT("xml parse 200", json_status(parsed) == 200);
    xml = transform_dict_to_xml("{\"item\":\"ok\"}", "root");
    ASSERT("xml build 200", json_status(xml) == 200);
    free(parsed);
    free(xml);
}

TEST(test_xml_parse_error)
{
    char *json = transform_xml_to_dict("<root");
    ASSERT("xml 400", json_status(json) == 400);
    free(json);
}

int main(void)
{
    RUN(test_json_parse_success);
    RUN(test_json_parse_error);
    RUN(test_json_stringify);
    RUN(test_csv_roundtrip);
    RUN(test_csv_empty_rows_error);
    RUN(test_xml_roundtrip);
    RUN(test_xml_parse_error);
    printf("transform tests passed\n");
    return 0;
}
