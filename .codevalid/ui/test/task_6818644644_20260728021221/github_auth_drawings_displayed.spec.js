import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGithubAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  githubDrawingsResponse,
} from "../../mock/mock-data.js";

test("Drawings are displayed and associated with GitHub identity after GitHub login", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "github_auth_drawings_displayed",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock GitHub-authenticated session and drawings API");
  await mockGithubAuthenticatedSession(page);
  await mockDrawingsList(page, githubDrawingsResponse);

  await recorder.step("Open draw page and verify GitHub sign-in entry point");
  await page.goto("/draw");
  await expect(page.getByRole("button", { name: "Sign-in with GitHub" })).toBeVisible();

  await recorder.step("Trigger GitHub sign-in and load drawings index page");
  await Promise.all([
    page.waitForURL(/\/$/),
    page.goto("/"),
  ]);

  await recorder.step("Assert GitHub drawings and identity metadata are visible");
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toBeVisible();
  await expect(page.getByText("GitHub User")).toBeVisible();
  await expect(page.getByRole("img", { name: "AI image generated of GitHub drawing" })).toBeVisible();
  await expect(page.getByRole("img", { name: "Google drawing" })).toHaveCount(0);
  await expect(page.getByText("Google User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:github_auth_drawings_displayed");
  await recorder.save(testInfo);
});
