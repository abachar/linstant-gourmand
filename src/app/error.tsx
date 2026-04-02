"use client";

import { DefaultErrorComponent } from "@components/defaults";

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
	return <DefaultErrorComponent error={error} reset={reset} />;
}
