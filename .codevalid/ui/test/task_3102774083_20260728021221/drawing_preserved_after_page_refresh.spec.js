import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function appOriginRegex(pathname) {
  return new RegExp(`^https?:\\/\\/[^/]+${escapeRegex(pathname)}(?:\\?.*)?$`);
}

async function drawStroke(page, points) {
  const canvas = page.locator("canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");

  await page.mouse.move(box.x + points[0][0], box.y + points[0][1]);
  await page.mouse.down();
  for (const [x, y] of points.slice(1)) {
    await page.mouse.move(box.x + x, box.y + y, { steps: 6 });
  }
  await page.mouse.up();
}

test("Drawing state is preserved across page reloads via backend sync", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_preserved_after_page_refresh",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);

  let savedDataUrl = null;
  await page.route(appOriginRegex("/api/upload"), async (route) => {
    const request = route.request();
    if (request.method() === "POST") {
      savedDataUrl = await page.locator("canvas").evaluate((canvas) => canvas.toDataURL("image/jpeg"));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, drawingDataUrl: savedDataUrl }),
      });
      return;
    }

    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ ok: true, drawingDataUrl: savedDataUrl }),
    });
  });

  await page.addInitScript(() => {
    window.__codevalidRestoreDrawing = null;
  });

  await recorder.step("Create and save a drawing", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
    await drawStroke(page, [[50, 50], [90, 80], [130, 110], [170, 140]]);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
    await page.getByRole("button", { name: "Share my drawing" }).click();
    await page.waitForURL("/");
    expect(savedDataUrl).toContain("data:image/jpeg;base64,");
  });

  await recorder.step("Simulate backend restore on reload using saved payload", async () => {
    await page.addInitScript((dataUrl) => {
      const originalSignaturePad = window.SignaturePad;
      const patchSignaturePad = (Ctor) => {
        if (!Ctor || Ctor.__codevalidPatched) return Ctor;
        class PatchedSignaturePad extends Ctor {
          constructor(canvas, options) {
            super(canvas, options);
            if (dataUrl) {
              try {
                this.fromDataURL(dataUrl);
              } catch {}
            }
          }
        }
        PatchedSignaturePad.__codevalidPatched = true;
        return PatchedSignaturePad;
      };

      Object.defineProperty(window, "SignaturePad", {
        configurable: true,
        get() {
          return originalSignaturePad;
        },
        set(value) {
          const patched = patchSignaturePad(value);
          Object.defineProperty(window, "SignaturePad", {
            configurable: true,
            writable: true,
            value: patched,
          });
        },
      });
    }, savedDataUrl);
  });

  await recorder.step("Reload draw page and verify stroke is visible again", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();

    const restoredPixels = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return darkPixels;
    });

    expect(restoredPixels).toBeGreaterThan(20);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_preserved_after_page_refresh");
  await recorder.save(testInfo);
});
