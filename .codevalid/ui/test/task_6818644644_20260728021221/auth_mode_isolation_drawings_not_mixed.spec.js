import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockGithubAuthenticatedSession,
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  googleOnlyIsolationResponse,
  githubOnlyIsolationResponse,
  anonymousOnlyIsolationResponse,
} from "../../mock/mock-data.js";

test("Drawings from different auth modes are isolated and not mixed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "auth_mode_isolation_drawings_not_mixed",
    testTitle: testInfo.title,
  });

  await recorder.step("Load Google session and verify only Google drawing is shown");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, googleOnlyIsolationResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toHaveCount(0);
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toHaveCount(0);

  await recorder.step("Open fresh page for GitHub session and verify only GitHub drawing is shown");
  const githubPage = await page.context().newPage();
  await mockGithubAuthenticatedSession(githubPage);
  await mockDrawingsList(githubPage, githubOnlyIsolationResponse);
  await githubPage.goto("/");
  await expect(githubPage.getByRole("img", { name: "GitHub drawing" })).toBeVisible();
  await expect(githubPage.getByText("GitHub User")).toBeVisible();
  await expect(githubPage.getByRole("img", { name: "Google drawing" })).toHaveCount(0);
  await expect(githubPage.getByRole("img", { name: "Anonymous drawing" })).toHaveCount(0);

  await recorder.step("Open fresh page for anonymous session and verify only anonymous drawing is shown");
  const anonymousPage = await page.context().newPage();
  await mockAnonymousOnlySession(anonymousPage);
  await mockDrawingsList(anonymousPage, anonymousOnlyIsolationResponse);
  await anonymousPage.goto("/");
  await expect(anonymousPage.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(anonymousPage.getByText("Anonymous User")).toBeVisible();
  await expect(anonymousPage.getByRole("img", { name: "Google drawing" })).toHaveCount(0);
  await expect(anonymousPage.getByRole("img", { name: "GitHub drawing" })).toHaveCount(0);

  await githubPage.close();
  await anonymousPage.close();

  console.log("CODEVALID_TEST_ASSERTION_OK:auth_mode_isolation_drawings_not_mixed");
  await recorder.save(testInfo);
});
