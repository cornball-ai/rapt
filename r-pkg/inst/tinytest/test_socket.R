# Test socket functions

# daemon_available should return FALSE when no daemon running
# (unless running in an environment with raptd)
avail <- rapt:::daemon_available()
expect_true(is.logical(avail))
expect_equal(length(avail), 1L)

# rapt_call should return NULL when daemon unavailable
if (!avail) {
    result <- rapt:::rapt_call("install test")
    expect_null(result)
}

# parse_response with NULL (daemon unavailable)
parsed <- rapt:::parse_response(NULL)
expect_equal(parsed$status, -1L)
expect_true(grepl("not available", parsed$output))

# parse_response with valid response
parsed <- rapt:::parse_response("some output\nSTATUS 0")
expect_equal(parsed$status, 0L)
expect_equal(parsed$output, "some output")

# parse_response with non-zero status
parsed <- rapt:::parse_response("error message\nSTATUS 1")
expect_equal(parsed$status, 1L)
expect_equal(parsed$output, "error message")

# parse_response with multi-line output
parsed <- rapt:::parse_response("line1\nline2\nline3\nSTATUS 0")
expect_equal(parsed$status, 0L)
expect_equal(parsed$output, "line1\nline2\nline3")

# parse_response with no STATUS line
parsed <- rapt:::parse_response("garbage")
expect_equal(parsed$status, -1L)
