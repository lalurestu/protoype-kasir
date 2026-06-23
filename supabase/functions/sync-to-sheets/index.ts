import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSign } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { encode as base64url } from "https://deno.land/std@0.168.0/encoding/base64url.ts";

// Utility to create JWT for Google Service Account
async function getGoogleAccessToken(clientEmail: string, privateKey: string) {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/spreadsheets",
    aud: "https://oauth2.googleapis.com/token",
    exp,
    iat,
  };

  const headerB64 = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signatureInput = `${headerB64}.${payloadB64}`;

  // Import private key for signing
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKey.substring(
    privateKey.indexOf(pemHeader) + pemHeader.length,
    privateKey.indexOf(pemFooter)
  ).replace(/\s/g, '');
  
  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signatureInput)
  );

  const signatureB64 = base64url(new Uint8Array(signature));
  const jwt = `${signatureInput}.${signatureB64}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Failed to get access token: ${JSON.stringify(data)}`);
  }

  return data.access_token;
}

serve(async (req) => {
  try {
    // 1. Get Environment Variables
    const clientEmail = Deno.env.get('GOOGLE_CLIENT_EMAIL');
    const privateKey = Deno.env.get('GOOGLE_PRIVATE_KEY'); // Note: Replace \n with actual newlines in Supabase Secrets
    const spreadsheetId = Deno.env.get('GOOGLE_SHEET_ID');
    const sheetName = 'Transactions'; // Ensure this sheet exists

    if (!clientEmail || !privateKey || !spreadsheetId) {
      throw new Error("Missing Google API credentials in environment variables");
    }

    // 2. Parse Webhook Payload from Supabase
    const payload = await req.json();
    console.log("Received webhook payload:", payload);

    // Only process INSERT events on transactions table
    if (payload.type === 'INSERT' && payload.table === 'transactions') {
      const record = payload.record;

      // 3. Format Data for Google Sheets
      // Row format: ID, Store ID, Kasir ID, Total, Payment Method, Status, Created At
      const rowData = [
        record.id,
        record.store_id,
        record.kasir_id,
        record.total_amount,
        record.payment_method,
        record.status,
        record.created_at
      ];

      // 4. Get Google Access Token
      const accessToken = await getGoogleAccessToken(clientEmail, privateKey.replace(/\\n/g, '\n'));

      // 5. Append Row to Google Sheets
      const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${sheetName}!A:G:append?valueInputOption=USER_ENTERED`;
      
      const sheetResponse = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          values: [rowData],
        }),
      });

      const sheetData = await sheetResponse.json();
      if (!sheetResponse.ok) {
        throw new Error(`Failed to append to Google Sheets: ${JSON.stringify(sheetData)}`);
      }

      return new Response(JSON.stringify({ success: true, message: "Row appended successfully", data: sheetData }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    return new Response(JSON.stringify({ success: true, message: "Ignored: Not an INSERT event on transactions" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error processing webhook:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
