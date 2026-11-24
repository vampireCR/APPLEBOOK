-- TheAppleBook: fixes for channel views, moderation revoke, message actions and profile gift showcase.
-- Safe to run repeatedly. Existing records are preserved.

-- 1) Older channel_posts tables may not have the counter column.
ALTER TABLE public.channel_posts
  ADD COLUMN IF NOT EXISTS views_count bigint NOT NULL DEFAULT 0;

-- 2) Personal messages: edit/delete/reply support.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS reply_to_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'messages_reply_to_id_fkey'
      AND conrelid = 'public.messages'::regclass
  ) THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_reply_to_id_fkey
      FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) ON DELETE SET NULL;
  END IF;
END $$;

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
GRANT UPDATE (content, edited_at) ON public.messages TO authenticated;
GRANT DELETE ON public.messages TO authenticated;
DROP POLICY IF EXISTS messages_sender_update_own ON public.messages;
CREATE POLICY messages_sender_update_own ON public.messages
  FOR UPDATE TO authenticated
  USING (sender_id = (SELECT auth.uid()))
  WITH CHECK (sender_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS messages_sender_delete_own ON public.messages;
CREATE POLICY messages_sender_delete_own ON public.messages
  FOR DELETE TO authenticated
  USING (sender_id = (SELECT auth.uid()));

-- 3) Gifts can be optionally displayed on the recipient's profile.
ALTER TABLE public.sent_gifts
  ADD COLUMN IF NOT EXISTS show_on_profile boolean NOT NULL DEFAULT false;
GRANT UPDATE (show_on_profile) ON public.sent_gifts TO authenticated;

DROP POLICY IF EXISTS "participants read sent gifts" ON public.sent_gifts;
DROP POLICY IF EXISTS sent_gifts_participants_or_showcase_read ON public.sent_gifts;
CREATE POLICY sent_gifts_participants_or_showcase_read ON public.sent_gifts
  FOR SELECT TO authenticated
  USING (
    sender_id = (SELECT auth.uid())
    OR recipient_id = (SELECT auth.uid())
    OR show_on_profile = true
  );

DROP POLICY IF EXISTS sent_gifts_recipient_update_showcase ON public.sent_gifts;
CREATE POLICY sent_gifts_recipient_update_showcase ON public.sent_gifts
  FOR UPDATE TO authenticated
  USING (recipient_id = (SELECT auth.uid()))
  WITH CHECK (recipient_id = (SELECT auth.uid()));

-- 4) Fix ambiguous `reason` reference in the revoke-sanction RPC.
-- Drop/recreate because PostgreSQL does not allow changing an input argument name via CREATE OR REPLACE.
DROP FUNCTION IF EXISTS public.admin_revoke_sanction(bigint, text);
CREATE FUNCTION public.admin_revoke_sanction(
  target_sanction_id bigint,
  revoke_reason_text text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor_role text;
BEGIN
  actor_role := private.current_role();
  IF actor_role NOT IN ('owner','ceo','deputy_ceo','admin','moderator') THEN
    RAISE EXCEPTION 'Insufficient permissions';
  END IF;
  IF char_length(trim(coalesce(revoke_reason_text,''))) < 3 THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  UPDATE public.account_sanctions AS s
    SET revoked_at = now(),
        revoked_by = auth.uid(),
        revoke_reason = trim(revoke_reason_text)
    WHERE s.id = target_sanction_id AND s.revoked_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sanction not found or already revoked';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_revoke_sanction(bigint,text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_sanction(bigint,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
