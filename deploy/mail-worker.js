// Cloudflare Email Worker "meio-mail": catch-all for @meio.lol (Email Routing). Every
// message is kept whole (raw RFC 822) in KV namespace meio-mail, keyed by arrival time so
// a listing is in order; deploy/mail.sh deploys this and reads the mail. Then forwarded
// to FORWARD_TO (a verified Email Routing destination; never published).
export default {
  async email(message, env) {
    const raw = await new Response(message.raw).arrayBuffer();
    const key = `msg/${new Date().toISOString()}-${crypto.randomUUID().slice(0, 8)}`;
    // KV metadata is capped at 1 KiB
    const subject = (message.headers.get('subject') ?? '').slice(0, 300);
    await env.MAIL.put(key, raw, {
      metadata: {
        from: message.from.slice(0, 200), to: message.to.slice(0, 200), subject,
      },
    });
    // Kept first, so an unverified or failing destination loses nothing
    if (env.FORWARD_TO) await message.forward(env.FORWARD_TO).catch(e => console.log(e));
  },
};
