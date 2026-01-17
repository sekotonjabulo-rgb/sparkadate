import crypto from 'crypto';
import { Resend } from 'resend';

// Email service using Resend
const APP_URL = process.env.APP_URL || 'https://sparkadate.online';
const EMAIL_FROM = process.env.EMAIL_FROM || 'Spark <noreply@sparkadate.online>';

// Initialize Resend client
const resend = new Resend(process.env.RESEND_API_KEY);

// Generate a secure token
export function generateToken() {
    return crypto.randomBytes(32).toString('hex');
}

// Generate a 6-digit verification code
export function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send email using Resend
export async function sendEmail(to, subject, html) {
    try {
        const { data, error } = await resend.emails.send({
            from: EMAIL_FROM,
            to: [to],
            subject,
            html
        });

        if (error) {
            console.error('Resend error:', error);
            throw new Error(`Email send failed: ${error.message}`);
        }

        console.log('Email sent successfully:', data?.id);
        return { success: true, id: data?.id };
    } catch (error) {
        console.error('Email service error:', error);
        throw error;
    }
}

export async function sendVerificationEmail(email, code) {
    const subject = 'Verify your Spark account';
    const html = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1 style="color: #000; font-size: 24px; margin-bottom: 20px;">Verify your email</h1>
            <p style="color: #333; font-size: 16px; line-height: 1.5;">
                Enter this code to verify your Spark account:
            </p>
            <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #000;">${code}</span>
            </div>
            <p style="color: #666; font-size: 14px;">
                This code expires in 15 minutes. If you didn't create a Spark account, you can ignore this email.
            </p>
        </div>
    `;

    return sendEmail(email, subject, html);
}

export async function sendPasswordResetEmail(email, token) {
    const resetUrl = `${APP_URL}/reset-password.html?token=${token}`;
    const subject = 'Reset your Spark password';
    const html = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1 style="color: #000; font-size: 24px; margin-bottom: 20px;">Reset your password</h1>
            <p style="color: #333; font-size: 16px; line-height: 1.5;">
                We received a request to reset your Spark password. Click the button below to choose a new password:
            </p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${resetUrl}" style="display: inline-block; background: #000; color: #fff; padding: 14px 32px; border-radius: 28px; text-decoration: none; font-weight: 500; font-size: 16px;">
                    Reset Password
                </a>
            </div>
            <p style="color: #666; font-size: 14px;">
                This link expires in 1 hour. If you didn't request a password reset, you can ignore this email.
            </p>
            <p style="color: #999; font-size: 12px; margin-top: 30px;">
                Or copy this link: ${resetUrl}
            </p>
        </div>
    `;

    return sendEmail(email, subject, html);
}
