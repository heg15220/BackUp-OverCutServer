package overcut.utils;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    @Autowired
    private JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String mailUser;

    @Value("${app.public-base-url:https://overcutf1.com}")
    private String publicBaseUrl;

    public void sendConfirmationEmail(String toEmail, String userName, String token) throws MessagingException {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom(mailUser);
        helper.setTo(toEmail);
        helper.setSubject("✅ Registro exitoso en OverCut / Successful Sign Up at OverCut");

        // ✅ BrowserRouter: URL limpia (sin /#/)
        String confirmationUrl = publicBaseUrl + "/verify-email?token=" + token;

        String textAlt =
            "Welcome to OverCut, " + userName + "!\n" +
            "Activate your account: " + confirmationUrl + "\n\n" +
            "¡Bienvenido! Activa tu cuenta: " + confirmationUrl;

        String content =
            "<h2>Welcome to OverCut, " + userName + "!</h2>" +
            "<p>Your account has been successfully created. To activate it, click the button below:</p>" +
            "<a href=\"" + confirmationUrl + "\" " +
            "style=\"display: inline-block; padding: 10px 20px; background-color: #28A745; color: white; " +
            "text-decoration: none; border-radius: 5px;\">Activate Account</a>" +
            "<hr>" +
            "<h2>¡Bienvenido a OverCut, " + userName + "!</h2>" +
            "<p>Tu cuenta ha sido registrada correctamente. Para activar tu cuenta, haz clic en el siguiente botón:</p>" +
            "<a href=\"" + confirmationUrl + "\" " +
            "style=\"display: inline-block; padding: 10px 20px; background-color: #007BFF; color: white; " +
            "text-decoration: none; border-radius: 5px;\">Activar cuenta</a>";

        helper.setText(textAlt, content);
        mailSender.send(message);
    }

    public void sendPasswordChangeEmail(String toEmail, String userName, String token) throws MessagingException {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom(mailUser);
        helper.setTo(toEmail);
        helper.setSubject("Overcut - 🔐 Confirmación de cambio de contraseña / Password Change Confirmation");

        // ✅ BrowserRouter: URL limpia (sin /#/)
        String confirmationUrl = publicBaseUrl + "/confirm-password-change?token=" + token;

        String textAlt =
            "Hello, " + userName + "\n" +
            "You requested to change your OverCut password.\n" +
            "Confirm here: " + confirmationUrl + "\n\n" +
            "Hola, " + userName + "\n" +
            "Has solicitado cambiar tu contraseña en OverCut.\n" +
            "Confirma aquí: " + confirmationUrl + "\n";

        String content =
            "<h2>Hello, " + userName + "</h2>" +
            "<p>You have requested to change your password on OverCut. To confirm and apply the change, click the button below:</p>" +
            "<a href=\"" + confirmationUrl + "\" " +
            "style=\"display: inline-block; padding: 10px 20px; background-color: #17A2B8; color: white; " +
            "text-decoration: none; border-radius: 5px;\">Confirm new password</a>" +
            "<hr>" +
            "<h2>Hola, " + userName + "</h2>" +
            "<p>Has solicitado cambiar tu contraseña en OverCut. Para confirmar y aplicar el cambio, haz clic en el siguiente botón:</p>" +
            "<a href=\"" + confirmationUrl + "\" " +
            "style=\"display: inline-block; padding: 10px 20px; background-color: #FFC107; color: black; " +
            "text-decoration: none; border-radius: 5px;\">Confirmar nueva contraseña</a>";

        helper.setText(textAlt, content);
        mailSender.send(message);
    }

    public void sendPasswordResetEmail(String toEmail, String userName, String token) throws MessagingException {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom(mailUser);
        helper.setTo(toEmail);
        helper.setSubject("OverCut - 🔁 Reset password / Restablecer contraseña");

        // ✅ BrowserRouter: URL limpia (sin /#/)
        String resetUrl = publicBaseUrl + "/reset-password?token=" + token;

        String textAlt =
            "Hello, " + userName + "\n" +
            "Reset your OverCut password here: " + resetUrl + "\n\n" +
            "Hola, " + userName + "\n" +
            "Restablece tu contraseña de OverCut aquí: " + resetUrl + "\n";

        String content =
            "<h2>Hello, " + userName + "</h2>" +
            "<p>Click the button below to reset your password:</p>" +
            "<a href=\"" + resetUrl + "\" " +
            "style=\"display:inline-block;padding:10px 20px;background-color:#6f42c1;color:white;" +
            "text-decoration:none;border-radius:6px;\">Reset password</a>" +
            "<hr>" +
            "<h2>Hola, " + userName + "</h2>" +
            "<p>Haz clic en el botón para restablecer tu contraseña:</p>" +
            "<a href=\"" + resetUrl + "\" " +
            "style=\"display:inline-block;padding:10px 20px;background-color:#fd7e14;color:black;" +
            "text-decoration:none;border-radius:6px;\">Restablecer contraseña</a>";

        helper.setText(textAlt, content);
        mailSender.send(message);
    }
}
