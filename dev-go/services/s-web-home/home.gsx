package module

component Home(lights []light, listFailed bool, roomTemp string) {
	<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1"/>
			<title>Home</title>
			<style>
				:root {
					--bg: #f6f4ef;
					--card: #ffffff;
					--text: #24211d;
					--muted: #8c857b;
					--line: rgb(36 33 29 / 8%);
					--amber: #e8a33d;
					--amber-soft: #fdf3e1;
					--off: #d9d4cb;
					--water: #3c7f9e;
					--brick: #a8502a;
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
				.room {
					display: flex;
					align-items: baseline;
					gap: 0.5rem;
					margin-bottom: 1rem;
				}
				.room strong {
					font-size: 2.5rem;
					font-weight: 200;
					letter-spacing: -0.02em;
					font-variant-numeric: tabular-nums;
				}
				.label {
					font-size: 0.75rem;
					color: var(--muted);
					text-transform: uppercase;
					letter-spacing: 0.08em;
				}
				.light {
					padding: 0.75rem 0.9rem;
					margin-bottom: 0.5rem;
					border-radius: 0.9rem;
					background: var(--card);
					border: 1px solid var(--line);
					box-shadow: 0 1px 2px var(--line);
					transition: background 0.2s, border-color 0.2s;
				}
				.light.on {
					background: var(--amber-soft);
					border-color: rgb(232 163 61 / 45%);
				}
				.row {
					display: flex;
					align-items: center;
					justify-content: space-between;
					gap: 0.5rem;
				}
				.name {
					font-weight: 600;
				}
				.status {
					font-size: 0.8rem;
					color: var(--muted);
					font-variant-numeric: tabular-nums;
				}
				.tank {
					font-size: 0.8rem;
					color: var(--water);
					font-variant-numeric: tabular-nums;
				}
				form {
					margin: 0;
				}
				.toggle {
					display: block;
					width: 2.6rem;
					height: 1.5rem;
					border: none;
					border-radius: 1rem;
					background: var(--off);
					position: relative;
					cursor: pointer;
					transition: background 0.2s;
				}
				.toggle::after {
					content: "";
					position: absolute;
					top: 0.2rem;
					left: 0.2rem;
					width: 1.1rem;
					height: 1.1rem;
					border-radius: 50%;
					background: white;
					box-shadow: 0 1px 2px rgb(0 0 0 / 20%);
					transition: left 0.2s;
				}
				.toggle.on {
					background: var(--amber);
				}
				.toggle.on::after {
					left: 1.3rem;
				}
				.toggle:disabled {
					opacity: 0.4;
					cursor: not-allowed;
				}
				.brightness {
					display: flex;
					align-items: center;
					gap: 0.5rem;
					margin-top: 0.4rem;
				}
				.brightness input {
					flex: 1;
					min-width: 0;
					height: 0.25rem;
					appearance: none;
					border-radius: 1rem;
					background: var(--off);
					cursor: pointer;
				}
				.brightness input::-webkit-slider-thumb {
					appearance: none;
					width: 1rem;
					height: 1rem;
					border-radius: 50%;
					background: var(--amber);
					box-shadow: 0 1px 3px rgb(0 0 0 / 25%);
				}
				.brightness input::-moz-range-thumb {
					width: 1rem;
					height: 1rem;
					border: none;
					border-radius: 50%;
					background: var(--amber);
					box-shadow: 0 1px 3px rgb(0 0 0 / 25%);
				}
				.light:not(.on) .brightness input::-webkit-slider-thumb {
					background: var(--muted);
				}
				.light:not(.on) .brightness input::-moz-range-thumb {
					background: var(--muted);
				}
				.brightness output {
					min-width: 2.5rem;
					text-align: right;
					font-size: 0.8rem;
					color: var(--muted);
					font-variant-numeric: tabular-nums;
				}
				#light-error {
					color: var(--brick);
					font-size: 0.85rem;
				}
				@media (min-width: 50rem) {
					body {
						max-width: 62rem;
						padding-top: 3rem;
					}
					.plan {
						position: relative;
						aspect-ratio: 1094 / 800;
						background: url("/floorplan.svg") center / contain no-repeat;
					}
					.room {
						position: absolute;
						left: 47%;
						top: 62%;
						transform: translate(-50%, -50%);
						flex-direction: column;
						align-items: center;
						gap: 0;
						margin: 0;
					}
					.room strong {
						font-size: 3.5rem;
					}
					.light {
						position: absolute;
						width: 9rem;
						margin: 0;
						padding: 0.55rem 0.7rem;
						transform: translate(-50%, -50%);
						box-shadow: 0 2px 10px rgb(36 33 29 / 10%);
					}
					#light-plug103 {
						left: 34.7%;
						top: 90%;
					}
					#light-rgb105 {
						width: 11rem;
						left: 63.1%;
						top: 35%;
					}
					#light-plug104 {
						left: 63.3%;
						top: 10.4%;
					}
					#light-rgb108 {
						width: 11rem;
						left: 81.8%;
						top: 87.5%;
					}
					#light-plug106 {
						left: 89.6%;
						top: 70%;
					}
				}
			</style>
		</head>
		<body>
			<h1>Home</h1>
			{ if listFailed {
				<p>Could not load lights.</p>
			} }
			<p id="light-error" role="alert" hidden></p>
			<div class="plan">
				<div class="room">
					<strong id="room-temp">{roomTemp}</strong>
					<span class="label">Room</span>
				</div>
				{ for _, l := range lights {
					<LightRow l={l}/>
				} }
			</div>
			<script>
				let draggedRow = null;
				let pendingRow = null;

				function applyRow(row) {
					document.getElementById(row.id)?.replaceWith(row);
				}

				function showRow(html) {
					const template = document.createElement("template");
					template.innerHTML = html;
					const row = template.content.firstElementChild;
					if (row.id === draggedRow) {
						pendingRow = row;
					} else {
						applyRow(row);
					}
				}

				document.addEventListener("pointerdown", (event) => {
					if (event.target.matches("input[type=range]")) {
						draggedRow = event.target.closest(".light").id;
					}
				});

				function endDrag() {
					// runs after the slider's change event, which needs the slider to still be there
					setTimeout(() => {
						draggedRow = null;
						if (pendingRow) {
							applyRow(pendingRow);
							pendingRow = null;
						}
					});
				}
				document.addEventListener("pointerup", endDrag);
				document.addEventListener("pointercancel", endDrag);

				document.addEventListener("submit", async (event) => {
					event.preventDefault();
					const error = document.getElementById("light-error");
					try {
						const response = await fetch(event.target.action, {
							method: "POST",
							headers: { "X-Row-Only": "true" },
							body: new URLSearchParams(new FormData(event.target, event.submitter)),
						});
						if (!response.ok) {
							throw new Error(await response.text());
						}
						error.hidden = true;
						showRow(await response.text());
					} catch (err) {
						error.textContent = err.message;
						error.hidden = false;
					}
				});

				const events = new EventSource("/lights/events");
				events.addEventListener("light", (event) => showRow(event.data));
				for (const id of ["aquarium-temp", "room-temp"]) {
					events.addEventListener(id, (event) => {
						const temp = document.getElementById(id);
						if (temp) {
							temp.textContent = event.data;
						}
					});
				}
			</script>
		</body>
	</html>
}

component LightRow(l light) {
	<div id={ "light-" + l.ID } class={ "light", "on": l.Known && l.On }>
		<div class="row">
			<div>
				<div class="name">{l.ID}</div>
				<div class="status">
					{ if !l.Known {
						unknown
					} else if !l.On {
						off
					} else if l.Dimmable {
						on · {l.Brightness}%
					} else {
						on
					} }
				</div>
				{ if l.ID == aquariumLight {
					<div class="tank">tank <span id="aquarium-temp">{l.Temp}</span></div>
				} }
			</div>
			<form method="post" action={ "/lights/" + l.ID }>
				<button
					type="submit"
					name="on"
					value={l.NextOn()}
					class={ "toggle", "on": l.Known && l.On }
					aria-pressed={l.Pressed()}
					aria-label={ "Toggle " + l.ID }
					disabled={!l.Known}
				></button>
			</form>
		</div>
		{ if l.Dimmable && l.Known {
			<form class="brightness" method="post" action={ "/lights/" + l.ID }>
				<input
					type="range"
					name="brightness"
					min="1"
					max="100"
					value={l.Brightness}
					aria-label={ "Brightness of " + l.ID }
					oninput=js`this.nextElementSibling.value = this.value + '%'`
					onchange=js`this.form.requestSubmit()`
				/>
				<output>{l.Brightness}%</output>
			</form>
		} }
	</div>
}
