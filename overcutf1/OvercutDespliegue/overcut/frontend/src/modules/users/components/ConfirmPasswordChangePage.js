import React, { useEffect, useState } from "react";
import { Box, Typography, CircularProgress, Button, Container, Paper } from "@mui/material";
import { useNavigate } from "react-router-dom";
import { FormattedMessage } from "react-intl";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import ErrorIcon from "@mui/icons-material/Error";

const ConfirmPasswordChangePage = () => {
  const [status, setStatus] = useState("loading"); // 'loading', 'success', 'error'
  const navigate = useNavigate();

  useEffect(() => {
    // ✅ BrowserRouter: token desde querystring
    const token = new URLSearchParams(window.location.search).get("token");

    if (!token) {
      setStatus("error");
      return;
    }

    // ✅ En prod y dev con proxy / nginx: ruta relativa
    fetch(`/overcut/api/users/confirm-password-change?token=${encodeURIComponent(token)}`)
      .then((res) => {
        setStatus(res.ok ? "success" : "error");
      })
      .catch(() => setStatus("error"));
  }, []);

  const renderContent = () => {
    if (status === "loading") {
      return (
        <>
          <CircularProgress sx={{ mb: 2 }} />
          <Typography variant="h6">
            <FormattedMessage
              id="project.passwordChange.loading"
              defaultMessage="Validando tu solicitud..."
            />
          </Typography>
        </>
      );
    }

    if (status === "success") {
      return (
        <>
          <CheckCircleIcon sx={{ fontSize: 60, color: "green", mb: 2 }} />
          <Typography variant="h5" fontWeight="bold">
            <FormattedMessage
              id="project.users.confirmPasswordChange.success"
              defaultMessage="Tu contraseña se ha actualizado correctamente"
            />
          </Typography>
          <Button
            variant="contained"
            color="primary"
            sx={{ mt: 3 }}
            onClick={() => navigate("/")}
          >
            <FormattedMessage id="project.global.buttons.backHome" defaultMessage="Volver al inicio" />
          </Button>
        </>
      );
    }

    return (
      <>
        <ErrorIcon sx={{ fontSize: 60, color: "red", mb: 2 }} />
        <Typography variant="h5" fontWeight="bold">
          <FormattedMessage
            id="project.users.confirmPasswordChange.error"
            defaultMessage="El enlace no es válido o ya ha expirado"
          />
        </Typography>
        <Button
          variant="outlined"
          color="error"
          sx={{ mt: 3 }}
          onClick={() => navigate("/")}
        >
          <FormattedMessage
            id="project.global.buttons.backHome"
            defaultMessage="Volver al inicio"
          />
        </Button>
      </>
    );
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Container maxWidth="sm" sx={{ flexGrow: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Paper elevation={4} sx={{ p: 4, textAlign: "center", borderRadius: 3 }}>
          {renderContent()}
        </Paper>
      </Container>
    </Box>
  );
};

export default ConfirmPasswordChangePage;
