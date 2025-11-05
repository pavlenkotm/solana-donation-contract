/**
 * Webhook Integration Example
 *
 * This example demonstrates how to integrate the donation contract
 * with external services using webhooks for real-time notifications.
 */

import { Connection, PublicKey, Keypair } from "@solana/web3.js";
import { AnchorProvider, Program, Wallet } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";
import { createMonitor } from "../utils/monitor";
import { logger } from "../utils/logger";
import * as anchor from "@coral-xyz/anchor";

// Configuration
const WEBHOOK_URL = process.env.WEBHOOK_URL || "https://your-webhook-endpoint.com/donations";
const RPC_URL = process.env.RPC_URL || "https://api.devnet.solana.com";
const PROGRAM_ID = new PublicKey(process.env.PROGRAM_ID || "DoNaT1on1111111111111111111111111111111111111");

/**
 * Send webhook notification
 */
async function sendWebhook(event: any): Promise<void> {
  try {
    const response = await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Event-Type": event.type,
      },
      body: JSON.stringify({
        timestamp: new Date().toISOString(),
        event,
      }),
    });

    if (response.ok) {
      logger.success(`Webhook sent successfully for ${event.type}`);
    } else {
      logger.error(`Webhook failed: ${response.statusText}`);
    }
  } catch (error) {
    logger.error("Failed to send webhook", error);
  }
}

/**
 * Discord notification example
 */
async function sendDiscordNotification(donation: any): Promise<void> {
  const discordWebhookUrl = process.env.DISCORD_WEBHOOK_URL;
  if (!discordWebhookUrl) return;

  const embed = {
    title: "🎉 New Donation Received!",
    description: `A generous donation has been made to the vault.`,
    color: 0x00ff00,
    fields: [
      {
        name: "Amount",
        value: `${donation.amountSOL.toFixed(4)} SOL`,
        inline: true,
      },
      {
        name: "Donor",
        value: donation.donor.toString().slice(0, 8) + "...",
        inline: true,
      },
      {
        name: "Tier",
        value: donation.tier,
        inline: true,
      },
      {
        name: "Total Donated",
        value: `${(donation.totalDonated / 1e9).toFixed(4)} SOL`,
        inline: false,
      },
    ],
    timestamp: new Date().toISOString(),
  };

  try {
    await fetch(discordWebhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });
    logger.success("Discord notification sent");
  } catch (error) {
    logger.error("Failed to send Discord notification", error);
  }
}

/**
 * Slack notification example
 */
async function sendSlackNotification(donation: any): Promise<void> {
  const slackWebhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!slackWebhookUrl) return;

  const message = {
    text: "New Donation Received! 🎉",
    blocks: [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "New Donation Received! 🎉",
        },
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: `*Amount:*\n${donation.amountSOL.toFixed(4)} SOL`,
          },
          {
            type: "mrkdwn",
            text: `*Tier:*\n${donation.tier}`,
          },
          {
            type: "mrkdwn",
            text: `*Donor:*\n\`${donation.donor.toString().slice(0, 16)}...\``,
          },
          {
            type: "mrkdwn",
            text: `*Total Donated:*\n${(donation.totalDonated / 1e9).toFixed(4)} SOL`,
          },
        ],
      },
    ],
  };

  try {
    await fetch(slackWebhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(message),
    });
    logger.success("Slack notification sent");
  } catch (error) {
    logger.error("Failed to send Slack notification", error);
  }
}

/**
 * Email notification example (using a hypothetical email service)
 */
async function sendEmailNotification(donation: any): Promise<void> {
  const emailApiKey = process.env.EMAIL_API_KEY;
  const emailApiUrl = process.env.EMAIL_API_URL;
  const recipientEmail = process.env.NOTIFICATION_EMAIL;

  if (!emailApiKey || !emailApiUrl || !recipientEmail) return;

  const emailData = {
    to: recipientEmail,
    subject: "New Donation Received",
    html: `
      <h2>New Donation Received! 🎉</h2>
      <p><strong>Amount:</strong> ${donation.amountSOL.toFixed(4)} SOL</p>
      <p><strong>Donor:</strong> ${donation.donor.toString()}</p>
      <p><strong>Tier:</strong> ${donation.tier}</p>
      <p><strong>Total Vault Balance:</strong> ${(donation.totalDonated / 1e9).toFixed(4)} SOL</p>
      <p><strong>Timestamp:</strong> ${new Date().toLocaleString()}</p>
    `,
  };

  try {
    await fetch(emailApiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${emailApiKey}`,
      },
      body: JSON.stringify(emailData),
    });
    logger.success("Email notification sent");
  } catch (error) {
    logger.error("Failed to send email notification", error);
  }
}

/**
 * Main monitoring function
 */
async function main() {
  logger.info("Starting webhook integration monitor...");

  // Setup connection
  const connection = new Connection(RPC_URL, "confirmed");

  // Load wallet
  const wallet = Wallet.local();
  const provider = new AnchorProvider(connection, wallet, {
    commitment: "confirmed",
  });

  // Load program
  const program = anchor.workspace.Donation as Program<Donation>;

  // Derive PDAs
  const [vaultStatePDA] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault_state")],
    PROGRAM_ID
  );

  const [vaultPDA] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault")],
    PROGRAM_ID
  );

  logger.info(`Vault State PDA: ${vaultStatePDA.toString()}`);
  logger.info(`Vault PDA: ${vaultPDA.toString()}`);

  // Create monitor
  const monitor = createMonitor(connection, program, vaultStatePDA, vaultPDA, {
    pollInterval: 10000, // 10 seconds
    enableLogging: true,
    webhookUrl: WEBHOOK_URL,
  });

  // Listen to donation events
  program.addEventListener("DonationEvent", async (event, slot) => {
    const donationData = {
      type: "donation",
      donor: event.donor,
      amount: event.amount.toNumber(),
      amountSOL: event.amount.toNumber() / 1e9,
      totalDonated: event.totalDonated.toNumber(),
      tier: parseTier(event.donorTier),
      slot,
      timestamp: Date.now(),
    };

    logger.donation(donationData.amountSOL, donationData.donor.toString(), donationData.tier);

    // Send to webhook
    await sendWebhook(donationData);

    // Send platform-specific notifications
    await Promise.all([
      sendDiscordNotification(donationData),
      sendSlackNotification(donationData),
      sendEmailNotification(donationData),
    ]);
  });

  // Listen to withdrawal events
  program.addEventListener("WithdrawEvent", async (event, slot) => {
    const withdrawData = {
      type: "withdrawal",
      admin: event.admin,
      amount: event.amount.toNumber(),
      amountSOL: event.amount.toNumber() / 1e9,
      slot,
      timestamp: Date.now(),
    };

    logger.withdrawal(withdrawData.amountSOL, withdrawData.admin.toString());
    await sendWebhook(withdrawData);
  });

  // Listen to pause events
  program.addEventListener("PauseEvent", async (event, slot) => {
    const pauseData = {
      type: "pause",
      admin: event.admin,
      paused: event.paused,
      slot,
      timestamp: Date.now(),
    };

    logger.warn(`Contract ${pauseData.paused ? "PAUSED" : "UNPAUSED"} by ${pauseData.admin}`);
    await sendWebhook(pauseData);
  });

  // Start monitor
  await monitor.start();

  logger.success("Webhook integration monitor started successfully!");
  logger.info("Press Ctrl+C to stop...");

  // Keep process running
  process.on("SIGINT", () => {
    logger.info("\nStopping monitor...");
    monitor.stop();
    process.exit(0);
  });
}

/**
 * Parse tier from event
 */
function parseTier(tier: any): string {
  if (tier.bronze !== undefined) return "bronze";
  if (tier.silver !== undefined) return "silver";
  if (tier.gold !== undefined) return "gold";
  if (tier.platinum !== undefined) return "platinum";
  return "bronze";
}

// Run if this is the main module
if (require.main === module) {
  main().catch((error) => {
    logger.error("Fatal error", error);
    process.exit(1);
  });
}

export { sendWebhook, sendDiscordNotification, sendSlackNotification, sendEmailNotification };
