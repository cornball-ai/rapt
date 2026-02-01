#' @title Low-level socket communication with raptd
#' @name socket
#' @description Internal functions for communicating with the rapt daemon.
NULL

#' Default socket path
#' @noRd
SOCKET_PATH <- "/run/raptd.sock"

#' Send command to daemon
#'
#' @param cmd Command string (e.g., "install dplyr ggplot2")
#' @return Response string from daemon, or NULL if daemon unavailable
#' @noRd
rapt_call <- function(cmd) {
    path <- getOption("rapt.socket", SOCKET_PATH)
    .Call(C_rapt_call, path, cmd)
}

#' Check if daemon is available
#'
#' @return TRUE if daemon is running and accepting connections
#' @noRd
daemon_available <- function() {
    path <- getOption("rapt.socket", SOCKET_PATH)
    .Call(C_rapt_available, path)
}

#' Parse daemon response
#'
#' @param response Raw response string from daemon
#' @return List with components: status (integer), output (character)
#' @noRd
parse_response <- function(response) {
    if (is.null(response)) {
        return(list(status = -1L, output = "daemon not available"))
    }

    lines <- strsplit(response, "\n", fixed = TRUE)[[1]]

    # Find STATUS line (should be last non-empty line)
    status_idx <- grep("^STATUS ", lines)
    if (length(status_idx) == 0) {
        return(list(status = -1L, output = response))
    }

    status_line <- lines[max(status_idx)]
    status <- as.integer(sub("^STATUS ", "", status_line))

    # Everything before last STATUS line is output
    output_lines <- lines[seq_len(max(status_idx) - 1)]
    output <- paste(output_lines, collapse = "\n")

    list(status = status, output = output)
}
