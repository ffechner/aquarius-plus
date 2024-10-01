#include "TcpVFS.h"
#ifdef _WIN32
#include <ws2tcpip.h>
#pragma comment(lib, "Ws2_32.lib")
#else
#include <netdb.h>
#endif

#define MAX_FDS (10)

struct state {
    bool in_use[MAX_FDS];

#ifndef _WIN32
    int sockets[MAX_FDS];
#else
    SOCKET sockets[MAX_FDS];
#endif
};

static struct state state;

TcpVFS::TcpVFS() {
}

TcpVFS &TcpVFS::instance() {
    static TcpVFS vfs;
    return vfs;
}

void TcpVFS::init() {
#ifdef _WIN32
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
#endif
}

static bool startsWith(const std::string &s1, const std::string &s2, bool caseSensitive = false) {
    if (caseSensitive) {
        return (strncasecmp(s1.c_str(), s2.c_str(), s2.size()) == 0);
    } else {
        return (strncmp(s1.c_str(), s2.c_str(), s2.size()) == 0);
    }
}

int TcpVFS::open(uint8_t flags, const std::string &_path) {
    (void)flags;
    printf("TCP open: %s\n", _path.c_str());

    if (!startsWith(_path, "tcp://")) {
        return ERR_PARAM;
    }
    auto colonPos = _path.find(':', 6);
    if (colonPos == std::string::npos) {
        return ERR_PARAM;
    }

    auto host    = _path.substr(6, colonPos - 6);
    auto portStr = _path.substr(colonPos + 1);

    char *endp;
    int   port = strtol(portStr.c_str(), &endp, 10);
    if (endp != portStr.c_str() + portStr.size() || port < 0 || port > 65535) {
        return ERR_PARAM;
    }

    printf("TCP host '%s'  port '%d'\n", host.c_str(), port);

    // Find free file descriptor
    int fd = -1;
    for (int i = 0; i < MAX_FDS; i++) {
        if (!state.in_use[i]) {
            fd = i;
            break;
        }
    }
    if (fd == -1)
        return ERR_TOO_MANY_OPEN;

    // Resolve name
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo *ai;
    if (getaddrinfo(host.c_str(), portStr.c_str(), &hints, &ai) != 0) {
        return ERR_NOT_FOUND;
    }

    printf("Name resolved!\n");

    // Open socket
    auto sock = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);

#ifndef _WIN32
    if (sock == -1) {
#else
    if (sock == INVALID_SOCKET) {
#endif
        freeaddrinfo(ai);
        return ERR_OTHER;
    }

#ifndef _WIN32
    if (fcntl(sock, F_SETFL, fcntl(sock, F_GETFL) | O_NONBLOCK) == -1) {
        ::close(sock);
        return ERR_OTHER;
    }
#endif

    printf("Socket opened!\n");

    // Connect to host
    int err = connect(sock, ai->ai_addr, (socklen_t)ai->ai_addrlen);
    freeaddrinfo(ai);

    if (err != 0) {
#ifndef _WIN32
        if (errno == EINPROGRESS) {
            struct timeval tv;
            tv.tv_sec  = 5;
            tv.tv_usec = 0;

            fd_set fdset;
            FD_ZERO(&fdset);
            FD_SET(sock, &fdset);

            // Connection in progress -> have to wait until the connecting socket is marked as writable, i.e. connection completes
            err = select(sock + 1, NULL, &fdset, NULL, &tv);
            if (err <= 0) {
                ::close(sock);
                return ERR_OTHER;
            }

        } else
#endif
        {
            printf("Error connecting to host!\n");
#ifndef _WIN32
            ::close(sock);
#else
            ::closesocket(sock);
#endif
            return ERR_NOT_FOUND;
        }
    }

    // Success!
    state.in_use[fd]  = true;
    state.sockets[fd] = sock;
    return fd;
}

int TcpVFS::read(int fd, size_t size, void *buf) {
    // printf("TCP read: %d  size: %u\n", fd, (unsigned)size);

    if (fd >= MAX_FDS || !state.in_use[fd])
        return ERR_PARAM;
    auto sock = state.sockets[fd];

    if (size == 0)
        return 0;

#ifdef _WIN32
    {
        u_long avail = 0;
        ioctlsocket(sock, FIONREAD, &avail);
        if (avail == 0)
            return 0;
        if (avail < size)
            size = avail;
    }
    int len = recv(sock, (char *)buf, (int)size, 0);
#else
    int len = recv(sock, buf, size, 0);
#endif

    if (len == 0)
        return ERR_EOF;

    if (len < 0) {
#ifndef _WIN32
        if (errno == EINPROGRESS || errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0; // Not an error
        }
        if (errno == ENOTCONN) {
            return ERR_EOF;
        }
#endif
        return ERR_OTHER;
    }
    return len;
}

int TcpVFS::write(int fd, size_t size, const void *buf) {
    // printf("TCP write: %d  size: %u\n", fd, (unsigned)size);

    if (fd >= MAX_FDS || !state.in_use[fd])
        return ERR_PARAM;
    auto sock = state.sockets[fd];

    if (size == 0)
        return 0;

    int         to_write = (int)size;
    const char *data     = (const char *)buf;
    while (to_write > 0) {
        int written = send(sock, data + (size - to_write), to_write, 0);
#ifndef _WIN32
        if (written < 0 && errno != EINPROGRESS && errno != EAGAIN && errno != EWOULDBLOCK)
            return ERR_OTHER;
#else
        if (written < 0) {
            int err = WSAGetLastError();
            if (err == WSAENOTCONN)
                return ERR_EOF;
            return ERR_OTHER;
        }
#endif

        if (written > 0)
            to_write -= written;
    }
    return (int)size;
}

int TcpVFS::close(int fd) {
    printf("TCP close: %d\n", fd);

    if (fd >= MAX_FDS || !state.in_use[fd])
        return ERR_PARAM;
#ifndef _WIN32
    ::close(state.sockets[fd]);
#else
    ::closesocket(state.sockets[fd]);
#endif
    state.in_use[fd]  = false;
    state.sockets[fd] = -1;

    return 0;
}
