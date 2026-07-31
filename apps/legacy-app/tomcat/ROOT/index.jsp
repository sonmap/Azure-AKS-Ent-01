<%@ page import="java.net.InetAddress" %>
<!DOCTYPE html>
<html lang="ko">
<head><meta charset="UTF-8"><title>AKS Legacy Migration PoC</title></head>
<body>
  <h1>Apache → Tomcat → MySQL Migration PoC</h1>
  <p>Tomcat Pod Host: <%= InetAddress.getLocalHost().getHostName() %></p>
  <p>DB Host: <%= System.getenv("DB_HOST") %></p>
  <p>DB Port: <%= System.getenv("DB_PORT") %></p>
  <p>이 페이지는 Apache Service를 거쳐 Tomcat Pod에서 처리되었습니다.</p>
</body>
</html>
