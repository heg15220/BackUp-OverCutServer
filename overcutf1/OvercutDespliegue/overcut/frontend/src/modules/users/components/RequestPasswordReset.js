import React, { useState } from "react";
import {
  Box,
  TextField,
  Button,
  Card,
  CardContent,
  Typography,
  Alert,
  CircularProgress
} from "@mui/material";
import { FormattedMessage } from "react-intl";
import { useNavigate } from "react-router-dom";
import { useDispatch } from "react-redux";
import * as actions from "../actions";

const RequestPasswordReset = () => {
  const [email, setEmail] = useState("");
  const [error, setError] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const dispatch = useDispatch();
  const navigate = useNavigate();

  const handleSubmit = (e) => {
    e.preventDefault();

    const cleanEmail = email.trim();
    if (!cleanEmail) return;

    setError(null);
    setIsSubmitting(true);

    dispatch(
      actions.requestPasswordReset(
        cleanEmail,
        () => {
          setIsSubmitting(false);
          navigate("/password-reset-requested");
        },
        () => {
          setIsSubmitting(false);
          setError("error");
        }
      )
    );
  };

  return (
    <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "100vh", m: 2 }}>
      <Card sx={{ width: "80%", maxWidth: 500 }}>
        <CardContent>
          <Typography variant="h5" align="center" sx={{ mb: 2 }}>
            <FormattedMessage
              id="project.users.requestPasswordReset.title"
              defaultMessage="Restablecer contraseña"
            />
          </Typography>

          <form onSubmit={handleSubmit}>
            <TextField
              label={<FormattedMessage id="project.global.fields.email" defaultMessage="Correo electrónico" />}
              fullWidth
              required
              margin="normal"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={isSubmitting}
            />

            <Button
              type="submit"
              fullWidth
              variant="contained"
              sx={{
                mt: 3,
                mb: 2,
                display: "flex",
                alignItems: "center",
                justifyContent: "center"
              }}
              disabled={isSubmitting || !email.trim()}
            >
              {isSubmitting ? (
                <>
                  <CircularProgress size={20} color="inherit" sx={{ mr: 1 }} />
                  <Typography variant="button">
                    <FormattedMessage
                      id="project.global.buttons.pleaseWait"
                      defaultMessage="Please wait..."
                    />
                  </Typography>
                </>
              ) : (
                <FormattedMessage
                  id="project.users.requestPasswordReset.send"
                  defaultMessage="Enviar email"
                />
              )}
            </Button>
          </form>

          {error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              <FormattedMessage
                id="project.global.errors.unexpected"
                defaultMessage="Ha ocurrido un error."
              />
            </Alert>
          )}
        </CardContent>
      </Card>
    </Box>
  );
};

export default RequestPasswordReset;
