package module

import "github.com/gsxhq/gsx"

component Page(title string, children gsx.Node) {
	<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1"/>
			<title>{title}</title>
			<style>
				:root {
					--bg: #f6f4ef;
					--card: #ffffff;
					--text: #24211d;
					--muted: #8c857b;
					--line: rgb(36 33 29 / 15%);
					--accent: #3c7f9e;
					--accent-soft: #e6f0f4;
					--error: #a8502a;
					--danger: #c62828;
					--danger-hover: #a51f1f;
				}
				* {
					box-sizing: border-box;
				}
				body {
					font: 15px/1.4 system-ui, sans-serif;
					color: var(--text);
					background: var(--bg);
					max-width: 32rem;
					margin: 0 auto;
					padding: 2rem 1rem;
					-webkit-font-smoothing: antialiased;
				}
				h1 {
					font-size: 1.1rem;
					font-weight: 600;
					letter-spacing: 0.02em;
					margin: 0 0 1.5rem;
				}
				.upload + .upload {
					margin-top: 1.5rem;
				}
				.drop {
					display: flex;
					align-items: center;
					justify-content: center;
					min-height: 10rem;
					padding: 1.5rem;
					text-align: center;
					background: var(--card);
					border: 2px dashed var(--line);
					border-radius: 12px;
					cursor: pointer;
					transition: border-color 0.15s, background 0.15s;
				}
				.drop:hover, .drop.over {
					border-color: var(--accent);
					background: var(--accent-soft);
				}
				.drop input {
					display: none;
				}
				.delete {
					display: block;
					width: 100%;
					margin-top: 0.5rem;
					padding: 0.7rem 1rem;
					font: inherit;
					color: #ffffff;
					background: var(--danger);
					border: 0;
					border-radius: 12px;
					cursor: pointer;
					transition: background 0.15s;
				}
				.delete:hover {
					background: var(--danger-hover);
				}
				.delete:disabled {
					opacity: 0.6;
					cursor: progress;
				}
				.status {
					margin: 0.75rem 0 0;
					color: var(--muted);
				}
				.status.error {
					color: var(--error);
				}
			</style>
		</head>
		<body>
			<h1>{title}</h1>
			{children}
			<script>
				async function errorMessage(response) {
					const isText = response.headers.get("Content-Type")?.startsWith("text/plain");
					return isText ? (await response.text()).trim() : response.status + " " + response.statusText;
				}

				for (const container of document.querySelectorAll(".upload")) {
					const form = container.querySelector("form");
					const drop = container.querySelector(".drop");
					const input = container.querySelector("input");
					const status = container.querySelector(".status");
					const deleteButton = container.querySelector(".delete");

					function showStatus(message, isError) {
						status.textContent = message;
						status.classList.toggle("error", isError);
						status.hidden = false;
					}

					async function upload(file) {
						showStatus("Uploading " + file.name + "…", false);
						const body = new FormData();
						body.append("file", file);
						try {
							const response = await fetch(form.action, { method: "POST", body });
							if (!response.ok) {
								throw new Error(await errorMessage(response));
							}
							showStatus("Uploaded " + file.name, false);
						} catch (err) {
							showStatus("Failed to upload " + file.name + ": " + err.message, true);
						}
					}

					input.addEventListener("change", () => {
						if (input.files.length > 0) {
							upload(input.files[0]);
							input.value = "";
						}
					});

					deleteButton?.addEventListener("click", async () => {
						if (!confirm(deleteButton.textContent.trim() + "?")) {
							return;
						}
						deleteButton.disabled = true;
						showStatus("Deleting…", false);
						try {
							const response = await fetch(form.action, { method: "DELETE" });
							if (!response.ok) {
								throw new Error(await errorMessage(response));
							}
							showStatus(await response.text(), false);
						} catch (err) {
							showStatus("Failed to delete: " + err.message, true);
						} finally {
							deleteButton.disabled = false;
						}
					});

					drop.addEventListener("dragover", (event) => {
						event.preventDefault();
						drop.classList.add("over");
					});
					drop.addEventListener("dragleave", () => drop.classList.remove("over"));
					drop.addEventListener("drop", (event) => {
						event.preventDefault();
						drop.classList.remove("over");
						const file = event.dataTransfer.files[0];
						if (file) {
							upload(file);
						}
					});
				}
			</script>
		</body>
	</html>
}

// DropZone renders a box to upload a file to action. If deleteLabel is not empty, it also renders a
// button with that label that sends a DELETE to action.
component DropZone(action string, accept string, label string, deleteLabel string) {
	<div class="upload">
		<form method="post" action={action} enctype="multipart/form-data">
			<label class="drop">
				<input type="file" name="file" accept={accept}/>
				{label}
			</label>
		</form>
		{ if deleteLabel != "" {
			<button type="button" class="delete">{deleteLabel}</button>
		} }
		<p class="status" hidden></p>
	</div>
}
