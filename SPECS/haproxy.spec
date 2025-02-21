%define haproxy_user    haproxy
%define haproxy_group   %{haproxy_user}
%define haproxy_homedir %{_localstatedir}/lib/haproxy
%define haproxy_confdir %{_sysconfdir}/haproxy
%define haproxy_datadir %{_datadir}/haproxy
 
%global _hardened_build 1
%global debug_package   %{nil}
 
Name:           haproxy-quic
Version:        %{haproxy_version}
Release:        1%{?dist}
Summary:        HAProxy reverse proxy for high availability environments
 
License:        GPLv2+
 
URL:            http://www.haproxy.org
Source0:        haproxy-%{version}.tar.gz
Source1:        haproxy.service
Source2:        haproxy.cfg
Source3:        haproxy.logrotate
Source4:        haproxy.sysconfig
Source5:        haproxy.sysusers
Source6:        halog.1
 
Source100:      aws-lc-%{aws_lc_version}.tar.gz

# AWS LC
BuildRequires:  cmake
BuildRequires:  perl-core
BuildRequires:  golang
BuildRequires:  ninja-build
BuildRequires:  libunwind-devel
BuildRequires:  libasan

# HAPROXY
BuildRequires:  make
BuildRequires:  gcc
BuildRequires:  systemd-devel
BuildRequires:  systemd
BuildRequires:  systemd-rpm-macros
BuildRequires:  lua-devel
BuildRequires:  pcre2-devel
BuildRequires:  zlib-devel

Requires(pre):  shadow-utils
%{?systemd_requires}
 
%description
HAProxy is a TCP/HTTP reverse proxy which is particularly suited for high
availability environments. Indeed, it can:
 - route HTTP requests depending on statically assigned cookies
 - spread load among several servers while assuring server persistence
   through the use of HTTP cookies
 - switch to backup servers in the event a main one fails
 - accept connections to special ports dedicated to service monitoring
 - stop accepting connections without breaking existing ones
 - add, modify, and delete HTTP headers in both directions
 - block requests matching particular patterns
 - report detailed status to authenticated users from a URI
   intercepted from the application
 
%prep
# HAPROXY
%setup -q -n haproxy-%{version}
# README renamed in 3.1.x
if [ -f README.md ]; then
    mv README.md README
fi
# AWS LC
%setup -q -T -D -a 100 -n haproxy-%{version}
 
%build
# AWS LC
pushd aws-lc-%{aws_lc_version}
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%{_tmppath} .
ninja run_tests
ninja install
popd

# HAPROXY
%{__make} %{?_smp_mflags} CPU="generic" TARGET="linux-glibc" USE_TFO=1 USE_LINUX_TPROXY=1 USE_SYSTEMD=1 USE_GETADDRINFO=1 USE_PROMEX=1 USE_LUA=1 USE_PCRE2=1 USE_PCRE2_JIT=1 USE_OPENSSL_AWSLC=1 USE_QUIC=1 USE_ZLIB=1 SSL_INC=%{_tmppath}/include SSL_LIB=%{_tmppath}/lib64 all
 
%{__make} admin/halog/halog ADDINC="%{build_cflags}" ADDLIB="%{build_ldflags}"

pushd admin/iprange
%{__make} OPTIMIZE="%{build_cflags}" LDFLAGS="%{build_ldflags}"
popd
 
%install
%{__make} install-bin DESTDIR=%{buildroot} PREFIX=%{_prefix} TARGET="linux2628"
%{__make} install-man DESTDIR=%{buildroot} PREFIX=%{_prefix}
 
%{__install} -p -D -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/haproxy.service
%{__install} -p -D -m 0644 %{SOURCE2} %{buildroot}%{haproxy_confdir}/haproxy.cfg
%{__install} -p -D -m 0644 %{SOURCE3} %{buildroot}%{_sysconfdir}/logrotate.d/haproxy
%{__install} -p -D -m 0644 %{SOURCE4} %{buildroot}%{_sysconfdir}/sysconfig/haproxy
%{__install} -p -D -m 0644 %{SOURCE5} %{buildroot}%{_sysusersdir}/haproxy.conf
%{__install} -p -D -m 0644 %{SOURCE6} %{buildroot}%{_mandir}/man1/halog.1
%{__install} -d -m 0755 %{buildroot}%{haproxy_homedir}
%{__install} -d -m 0755 %{buildroot}%{haproxy_datadir}
%{__install} -d -m 0755 %{buildroot}%{haproxy_confdir}/conf.d
%{__install} -d -m 0755 %{buildroot}%{_bindir}
%{__install} -p -m 0755 ./admin/halog/halog %{buildroot}%{_bindir}/halog
%{__install} -p -m 0755 ./admin/iprange/iprange %{buildroot}%{_bindir}/iprange
%{__install} -p -m 0755 ./admin/iprange/ip6range %{buildroot}%{_bindir}/ip6range
 
for httpfile in $(find ./examples/errorfiles/ -type f) 
do
    %{__install} -p -m 0644 $httpfile %{buildroot}%{haproxy_datadir}
done
 
%{__rm} -rf ./examples/errorfiles/
 
find ./examples/* -type f ! -name "*.cfg" -exec %{__rm} -f "{}" \;
 
for textfile in $(find ./ -type f -name '*.txt')
do
    %{__mv} $textfile $textfile.old
    iconv --from-code ISO8859-1 --to-code UTF-8 --output $textfile $textfile.old
    %{__rm} -f $textfile.old
done
 
%pre
%sysusers_create_compat %{SOURCE5}
 
%post
%systemd_post haproxy.service
 
%preun
%systemd_preun haproxy.service
 
%postun
%systemd_postun_with_restart haproxy.service
 
%files
%doc doc/* examples/*
%doc CHANGELOG README VERSION
%license LICENSE
%dir %{haproxy_homedir}
%dir %{haproxy_confdir}
%dir %{haproxy_confdir}/conf.d
%dir %{haproxy_datadir}
%{haproxy_datadir}/*
%config(noreplace) %{haproxy_confdir}/haproxy.cfg
%config(noreplace) %{_sysconfdir}/logrotate.d/haproxy
%config(noreplace) %{_sysconfdir}/sysconfig/haproxy
%{_unitdir}/haproxy.service
%{_sbindir}/haproxy
%{_bindir}/halog
%{_bindir}/iprange
%{_bindir}/ip6range
%{_mandir}/man1/*
%{_sysusersdir}/haproxy.conf
