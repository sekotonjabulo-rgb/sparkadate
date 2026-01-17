import crypto from 'crypto';

// Email service abstraction
// Supports multiple providers: Resend, SendGrid, or SMTP
// Configure via environment variables

const EMAIL_PROVIDER = process.env.EMAIL_PROVIDER || 'resend'; // 'resend', 'sendgrid', 'smtp', or 'console'
const APP_URL = process.env.APP_URL || 'https://sparkadate.online';

// Generate a secure token
export function generateToken() {
    return crypto.randomBytes(32).toString('hex');
}

// Generate a 6-digit verification code
export function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendWithResend(to, subject, html) {
    const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            from: process.env.EMAIL_FROM || 'Spark <noreply@sparkadate.online>',
            to: [to],
            subject,
            html
        })
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(`Resend error: ${error.message}`);
    }

    return response.json();
}

async function sendWithSendGrid(to, subject, html) {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${process.env.SENDGRID_API_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            personalizations: [{ to: [{ email: to }] }],
            from: { email: process.env.EMAIL_FROM || 'noreply@sparkadate.online' },
            subject,
            content: [{ type: 'text/html', value: html }]
        })
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`SendGrid error: ${error}`);
    }

    return { success: true };
}

async function sendWithConsole(to, subject, html) {
    // Development mode - log to console
    console.log('\n========== EMAIL ==========');
    console.log(`To: ${to}`);
    console.log(`Subject: ${subject}`);
    console.log(`Body: ${html.replace(/<[^>]*>/g, '')}`);
    console.log('===========================\n');
    return { success: true, mode: 'console' };
}

export async function sendEmail(to, subject, html) {
    switch (EMAIL_PROVIDER) {
        case 'resend':
            return sendWithResend(to, subject, html);
        case 'sendgrid':
            return sendWithSendGrid(to, subject, html);
        case 'console':
        default:
            return sendWithConsole(to, subject, html);
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
