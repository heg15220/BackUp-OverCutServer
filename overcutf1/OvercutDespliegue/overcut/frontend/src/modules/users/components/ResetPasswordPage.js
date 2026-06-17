// ResetPasswordPage.js
import React, { useEffect, useState } from "react";
import { Box, TextField, Button, Container, Paper, Typography, Alert } from "@mui/material";
import { FormattedMessage } from "react-intl";
import { useNavigate } from "react-router-dom";
import { useDispatch } from "react-redux";
import * as actions from "../actions";

const ResetPasswordPage = () => {
  const [status, setStatus] = useState("ready"); // ready | saving | success | error
  const [token, setToken] = useState(null);

  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");
  const [passwordsDoNotMatch, setPasswordsDoNotMatch] = useState(false);
  const [passwordValidation, setPasswordValidation] = useState({
    valid: true,
    lengthCheck: true,
    uppercaseCheck: true,
    numberCheck: true,
    specialCharCheck: true
  });

  const dispatch = useDispatch();
  const navigate = useNavigate();

  useEffect(() => {
    // ✅ BrowserRouter: token desde querystring ?token=...
    const qsToken = new URLSearchParams(window.location.search).get("token");

    // ✅ Compatibilidad por si aún llega algún email viejo con /#/reset-password?token=...
    const hashQuery = window.location.hash.includes("?")
      ? window.location.hash.split("?")[1]
      : "";
    const hashToken = hashQuery ? new URLSearchParams(hashQuery).get("token") : null;

    const t = qsToken || hashToken;

    if (!t) {
      setStatus("error");
      return;
    }
    setToken(t);
  }, []);

  const validatePassword = (password) => {
    const lengthCheck = password.length >= 8;
    const uppercaseCheck = /[A-Z]/.test(password);
    const numberCheck = /\d/.test(password);
    const specialCharCheck = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    return {
      valid: lengthCheck && uppercaseCheck && numberCheck && specialCharCheck,
      lengthCheck,
      uppercaseCheck,
      numberCheck,
      specialCharCheck
    };
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    const validation = validatePassword(newPassword);
    setPasswordValidation(validation);

    const match = newPassword === confirmNewPassword;
    setPasswordsDoNotMatch(!match);

    if (!validation.valid || !match || !token) return;

    setStatus("saving");

    dispatch(
      actions.resetPassword(
        token,
        newPassword,
        () => setStatus("success"),
        () => setStatus("error")
      )
    );
  };

  if (status === "success") {
    return (
      <Box sx={{ minHeight: "100vh", display: "flex" }}>
        <Container maxWidth="sm" sx={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Paper elevation={4} sx={{ p: 4, textAlign: "center", borderRadius: 3 }}>
            <Typography variant="h5" fontWeight="bold">
              <FormattedMessage
                id="project.users.passwordReset.success"
                defaultMessage="Tu contraseña se ha restablecido correctamente"
              />
            </Typography>
            <Button variant="contained" sx={{ mt: 3 }} onClick={() => navigate("/users/login")}>
              <FormattedMessage id="project.global.buttons.login" defaultMessage="Iniciar sesión" />
            </Button>
          </Paper>
        </Container>
      </Box>
    );
  }

  return (
    <Box sx={{ minHeight: "100vh", display: "flex" }}>
      <Container maxWidth="sm" sx={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Paper elevation={4} sx={{ p: 4, width: "100%", borderRadius: 3 }}>
          <Typography variant="h5" fontWeight="bold" align="center" sx={{ mb: 2 }}>
            <FormattedMessage id="project.users.passwordReset.title" defaultMessage="Nueva contraseña" />
          </Typography>

          {status === "error" && (
            <Alert severity="error" sx={{ mb: 2 }}>
              <FormattedMessage
                id="project.users.passwordReset.error"
                defaultMessage="El enlace no es válido o ya ha expirado"
              />
            </Alert>
          )}

          <form onSubmit={handleSubmit}>
            <TextField
              type="password"
              label={
                <FormattedMessage
                  id="project.users.ChangePassword.fields.newPassword"
                  defaultMessage="Nueva contraseña"
                />
              }
              fullWidth
              required
              margin="normal"
              value={newPassword}
              onChange={(e) => {
                const v = e.target.value;
                setNewPassword(v);
                setPasswordValidation(validatePassword(v));
              }}
              error={!passwordValidation.valid}
              helperText={
                !passwordValidation.valid && (
                  <ul style={{ margin: 0, paddingLeft: 20 }}>
                    {!passwordValidation.lengthCheck && (
                      <li><FormattedMessage id="validation.password.length" defaultMessage="At least 8 characters" /></li>
                    )}
                    {!passwordValidation.uppercaseCheck && (
                      <li><FormattedMessage id="validation.password.uppercase" defaultMessage="At least one uppercase letter" /></li>
                    )}
                    {!passwordValidation.numberCheck && (
                      <li><FormattedMessage id="validation.password.number" defaultMessage="At least one number" /></li>
                    )}
                    {!passwordValidation.specialCharCheck && (
                      <li><FormattedMessage id="validation.password.special" defaultMessage="At least one special character" /></li>
                    )}
                  </ul>
                )
              }
            />

            <TextField
              type="password"
              label={
                <FormattedMessage
                  id="project.users.ChangePassword.fields.confirmNewPassword"
                  defaultMessage="Repite la nueva contraseña"
                />
              }
              fullWidth
              required
              margin="normal"
              value={confirmNewPassword}
              onChange={(e) => setConfirmNewPassword(e.target.value)}
              error={passwordsDoNotMatch}
              helperText={
                passwordsDoNotMatch && (
                  <FormattedMessage
                    id="project.global.validator.passwordsDoNotMatch"
                    defaultMessage="Las contraseñas no coinciden"
                  />
                )
              }
            />

            <Button type="submit" variant="contained" fullWidth sx={{ mt: 2 }} disabled={status === "saving"}>
              <FormattedMessage id="project.global.buttons.save" defaultMessage="Guardar" />
            </Button>
          </form>
        </Paper>
      </Container>
    </Box>
  );
};

export default ResetPasswordPage;
